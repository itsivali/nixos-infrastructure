##############################################################################
#
# Home — GNOME Remote Desktop (RDP backend)
#
# Purpose
# -------
# Declaratively enables the per-user RDP backend for GNOME Remote
# Desktop (GRD). The system service + firewall are owned by the NixOS
# module (desktop/remote-desktop/grd.nix); this module owns the user
# session switch and behaviour keys.
#
# Behavior
# --------
# * RDP backend enabled at login
# * Port matches the system module (3389 default)
# * Mirror the primary screen (what is on the laptop display)
# * Remote control allowed (view-only = false)
# * TLS certificate ensured at each login by the bootstrap unit
#   (~/.local/share/gnome-remote-desktop/certs/). A self-healing self-
#   signed cert is generated when missing or when the CN/SAN drift from
#   the current Tailscale hostname/IP; dconf is repointed at it each
#   session.
# * Credentials stored in the GNOME keyring. The bootstrap unit reads the
#   SOPS-backed password (/run/secrets/rdp_password) and the username
#   from the system account, then pushes both into GRD via `grdctl rdp
#   set-credentials` under a pseudo-TTY (grdctl's credential prompt
#   requires a TTY and segfaults without one). Manual override remains
#   available with `ivali-remote-desktop credentials`.
#
# Sanity: when the host does not enable the system GRD module
# (ivali.desktop.remote-desktop.enable = false, the default), the RDP
# backend key is left untouched so the operator never sees a phantom
# "enabled but unlistening" state.
#
# Ownership
# ---------
# dconf.settings, hostSpec (host option enablement)
#
##############################################################################

{ config, lib, pkgs, hostSpec, ... }:

let
  hostConfig = hostSpec.config or { };
  remoteDesktop = hostConfig.ivali.desktop.remote-desktop or { enable = false; port = 3389; };
  enabled = remoteDesktop.enable or false;
  port = remoteDesktop.port or 3389;

  userName = config.home.username or "ivali";
  hostName = hostSpec.hostName or "prague";
  tailnetDomain = hostSpec.tailnetDomain or null;

  certDir = "${config.home.homeDirectory}/.local/share/gnome-remote-desktop/certs";
  tlsCert = "${certDir}/tls.crt";
  tlsKey = "${certDir}/tls.key";
  pwFile = "/run/secrets/rdp_password";

  bootStrap = pkgs.writeShellApplication {
    name = "ivali-rdp-bootstrap";

    runtimeInputs = with pkgs; [
      bash
      coreutils
      gnome-remote-desktop
      gnused
      iproute2
      openssl
      systemd
      util-linux
    ];

    text = ''
      set -euo pipefail

      cert_dir="${certDir}"
      cert="${tlsCert}"
      cert_key="${tlsKey}"
      host_name="${hostName}"
      tailnet_domain="${tailnetDomain}"
      pw_file="${pwFile}"
      username="${userName}"

      mkdir -p "$cert_dir"

      # ── resolve the tailnet IP (unprivileged) ──────────────────────────
      ts_ip="$(ip -4 -o addr show dev tailscale0 2>/dev/null | awk '{print $4}' | cut -d/ -f1 || true)"

      # ── ensure a valid self-signed certificate ─────────────────────────
      needs_gen=false
      [ -s "$cert" ] && [ -s "$cert_key" ] || needs_gen=true
      if [ "$needs_gen" = false ] && ! openssl x509 -in "$cert" -noout -subject 2>/dev/null | grep -q "/CN=$host_name"; then
        needs_gen=true
      fi
      if [ "$needs_gen" = false ] && [ -n "$tailnet_domain" ] && \
         ! openssl x509 -in "$cert" -noout -text 2>/dev/null | grep -q "DNS:$host_name.$tailnet_domain"; then
        needs_gen=true
      fi
      if [ "$needs_gen" = false ] && [ -n "$ts_ip" ] && \
         ! openssl x509 -in "$cert" -noout -text 2>/dev/null | grep -q "IP Address:$ts_ip"; then
        needs_gen=true
      fi

      if [ "$needs_gen" = true ]; then
        san=""
        [ -n "$tailnet_domain" ] && san="DNS:$host_name.$tailnet_domain"
        [ -n "$ts_ip" ] && san="$san''${san:+,}IP:$ts_ip"
        [ -z "$san" ] && san="DNS:localhost"
        openssl req -x509 -newkey rsa:2048 -nodes \
          -keyout "$cert_key" -out "$cert" -days 825 \
          -subj "/CN=$host_name" \
          -addext "subjectAltName=$san" >/dev/null 2>&1
        chmod 600 "$cert_key"
        echo "ivali-rdp-bootstrap: generated TLS certificate for $host_name ($san)"
      fi

      # ── point GRD at the certificate (idempotent) ──────────────────────
      grdctl rdp set-tls-cert "$cert" >/dev/null 2>&1 || true
      grdctl rdp set-tls-key  "$cert_key" >/dev/null 2>&1 || true

      # ── declarative credentials = system account + SOPS password ───────
      if [ -r "$pw_file" ]; then
        password="$(cat "$pw_file")"
        printf '%s\n%s\n' "$username" "$password" \
          | script -qec 'grdctl rdp set-credentials' /dev/null >/dev/null 2>&1 \
          || echo "ivali-rdp-bootstrap: warning: could not set RDP credentials (keyring unavailable?)" >&2
      else
        echo "ivali-rdp-bootstrap: warning: $pw_file not present; RDP credentials left to manual setup" >&2
      fi

      # ── ensure the backend is enabled and listening ────────────────────
      grdctl rdp enable >/dev/null 2>&1 || true
      systemctl --user start gnome-remote-desktop.service >/dev/null 2>&1 || true
    '';
  };

in
{
  dconf.settings = lib.mkIf enabled {
    "org/gnome/desktop/remote-desktop/rdp" = {
      enable = true;
      port = lib.hm.gvariant.mkUint16 port;
      # Port negotiation off: the Tailscale firewall only opens the
      # configured port. Negotiation could pick a port the firewall
      # blocked, silently breaking connections.
      negotiate-port = false;
      # Mirror the primary screen of the live session.
      screen-share-mode = "mirror-primary";
      # Allow remote input control.
      view-only = false;
      # TLS certificate paths (ensured by the bootstrap unit).
      tls-cert = tlsCert;
      tls-key = tlsKey;
    };
  };

  # Oneshot that runs at each graphical login: ensures the self-signed
  # TLS certificate exists and is valid for the current tailnet, repoints
  # GRD at it, and pushes the SOPS-backed credentials into the keyring so
  # RDP username/password always match the system account.
  systemd.user.services.ivali-rdp-bootstrap = lib.mkIf enabled {
    Unit = {
      Description = "Ensure GNOME Remote Desktop RDP certificate and credentials";
      After = [ "graphical-session.target" ];
    };

    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${bootStrap}/bin/ivali-rdp-bootstrap";
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
