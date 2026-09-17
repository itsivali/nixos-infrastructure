##############################################################################
#
# Home Manager — KDE Remote Desktop (KRDP)
#
# Purpose
# -------
# Declaratively enables the per-user KRDP RDP backend for KDE Plasma.
# The system service + firewall are owned by desktop/kde/remote-desktop.nix;
# this module owns the per-user:
#   * TLS certificate generation (self-signed, Tailscale-aware)
#   * krdpserverrc configuration (SystemUserEnabled + cert paths)
#   * Portal permission grant
#   * app-org.kde.krdpserver.service user unit enablement
#
# Security model
# --------------
# Authentication uses KRDP system-user auth (SystemUserEnabled=true):
# remote clients authenticate via PAM with the OS account password.
# No password is stored in KWallet or plaintext config.
# TLS uses a self-signed cert for the Tailscale hostname; clients see
# a one-time trust prompt.
#
# Ownership
# ---------
# dconf.settings, programs.plasma.configFile."krdpserver/krdpserverrc",
# systemd.user.services (KRDP bootstrap + server)
#
##############################################################################

{ config, lib, pkgs, hostSpec, ... }:

let
  hostConfig = hostSpec.config or { };
  remoteDesktop = hostConfig.ivali.desktop.remote-desktop or { enable = false; };
  enabled = remoteDesktop.enable or false;
  port = remoteDesktop.port or 3389;

  hostName = hostSpec.hostName or "prague";
  tailnetDomain = hostSpec.tailnetDomain or "codlet-trench.ts.net";
  userName = config.home.username or "ivali";

  certDir = "${config.home.homeDirectory}/.local/share/krdpserver";
  tlsCert = "${certDir}/krdp.crt";
  tlsKey = "${certDir}/krdp.key";

  bootstrap = pkgs.writeShellApplication {
    name = "ivali-krdp-bootstrap";

    runtimeInputs = with pkgs; [
      bash
      coreutils
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
      rc_file="''${XDG_CONFIG_HOME:-$HOME/.config}/krdpserver/krdpserverrc"

      mkdir -p "$cert_dir"
      mkdir -p "$(dirname "$rc_file")"

      # ── resolve the tailnet IP (unprivileged) ──────────────────────
      ts_ip="$(ip -4 -o addr show dev tailscale0 2>/dev/null | awk '{print $4}' | cut -d/ -f1 || true)"

      # ── ensure a valid self-signed certificate ─────────────────────
      needs_gen=false
      [ -s "$cert" ] && [ -s "$cert_key" ] || needs_gen=true
      if [ "$needs_gen" = false ] && ! openssl x509 -in "$cert" -noout -subject 2>/dev/null | grep -q "CN=$host_name"; then
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
        echo "ivali-krdp-bootstrap: generated TLS certificate for $host_name ($san)"
      fi

      # ── grant xdg-desktop-portal permission (system-user auth) ───
      # This allows the KDE Remote Desktop portal to activate without
      # flatpak. busctl is always available on systemd systems.
      busctl --user call org.freedesktop.impl.portal.PermissionStore \
        /org/freedesktop/impl/portal/PermissionStore \
        org.freedesktop.impl.portal.PermissionStore SetPermission \
        "sbssas" "kde-authorized" true "remote-desktop" "org.kde.krdpserver" 1 "yes" \
        2>/dev/null || echo "ivali-krdp-bootstrap: note: portal permission grant failed (non-critical)" >&2
    '';
  };

in
{
  config = lib.mkIf enabled {
    # ── krdpserverrc ───────────────────────────────────────────────────
    # KRDP reads: ListenPort, AutogenerateCertificates=false (we provide),
    # Certificate, CertificateKey, SystemUserEnabled, Autostart, Quality,
    # Users list.
    programs.plasma.configFile."krdpserver/krdpserverrc" = {
      General = {
        ListenPort = port;
        AutogenerateCertificates = false;
        Certificate = tlsCert;
        CertificateKey = tlsKey;
        SystemUserEnabled = true;
        Autostart = true;
        Quality = 75;
        Users = userName;
      };
    };

    # ── Bootstrap: ensure TLS cert + grant portal permission ──────────
    systemd.user.services.ivali-krdp-bootstrap = {
      Unit = {
        Description = "Ensure KRDP TLS certificate and portal permission";
        After = [ "graphical-session.target" "xdg-desktop-portal.service" ];
      };

      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${bootstrap}/bin/ivali-krdp-bootstrap";
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };

    # ── KRDP server user unit ─────────────────────────────────────────
    systemd.user.services.plasma-krdpserver = {
      Unit = {
        Description = "KRDP Remote Desktop Server";
        After = [ "ivali-krdp-bootstrap.service" "plasma-core.target" ];
      };

      Service = {
        Type = "exec";
        ExecStart = "${pkgs.kdePackages.krdp}/bin/krdpserver";
        Restart = "on-abnormal";
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
