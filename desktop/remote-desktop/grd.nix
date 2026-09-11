##############################################################################
#
# Desktop — Remote Desktop (GNOME Remote Desktop / RDP)
#
# Purpose
# -------
# Remote desktop access to the live GNOME session via Microsoft Remote
# Desktop Protocol (RDP). Provides:
#
#   * GNOME Remote Desktop service (v50+, daemon-based)
#   * RDP backend on the Tailscale network only (by default)
#   * A declarative user-session enablement unit
#   * Operator helper script (`ivali-remote-desktop`) for status,
#     certificate queries, and credential setup
#
# The GRD package itself exposes only `enable` on NixOS. Everything else
# (port, TLS, screen mirroring, view-only) is a per-user GSettings schema
# (`org.gnome.desktop.remote-desktop.rdp`) wired declaratively through
# the matching Home Manager module (`home/gnome/remote-desktop.nix`).
#
# Security model
# --------------
# * RDP port is opened ONLY on the `tailscale0` interface — the same
#   pattern used for SSH (see ssh/daemon.nix). The port stays closed on
#   the public internet.
# * Credentials are stored in the per-user GNOME keyring. The operator
#   sets them once with `ivali-remote-desktop credentials` (wrapper around
#   gnome-remote-desktop's secret setting API, or the GNOME Settings →
#   Sharing panel).
# * TLS uses GRD's auto-generated self-signed certificate
#   (~/.local/share/gnome-remote-desktop/certs/). Self-signed certs are
#   expected for RDP over an encrypted Tailscale overlay; clients present
#   a one-time trust prompt.
#
# Ownership
# ---------
# services.gnome.gnome-remote-desktop, networking.firewall,
# environment.systemPackages (helper script)
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.desktop.remote-desktop;
  grd = pkgs.gnome-remote-desktop;
in
{
  options.ivali.desktop.remote-desktop = {
    enable = lib.mkEnableOption ''
      GNOME Remote Desktop (RDP) access over Tailscale.

      Enables the GRD daemon and opens the RDP port on the tailscale0
      interface only. The per-user backend must be enabled in the user
      session as well; the corresponding Home Manager module
      (home/gnome/remote-desktop.nix) does this automatically when the
      user account has the GNOME desktop enabled.
    '';

    port = lib.mkOption {
      type = lib.types.port;
      default = 3389;
      description = "TCP port the RDP server listens on.";
    };

    tailscaleOnly = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Restrict the RDP port to the Tailscale interface. When disabled,
        the port is opened on all interfaces — not recommended.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # ── GNOME Remote Desktop service ────────────────────────────────────
    services.gnome.gnome-remote-desktop.enable = true;

    # ── Firewall: RDP on Tailscale only (mirrors ssh/daemon.nix) ────────
    networking.firewall.interfaces.tailscale0.allowedTCPPorts =
      lib.mkIf cfg.tailscaleOnly [ cfg.port ];
    networking.firewall.allowedTCPPorts = lib.mkIf (!cfg.tailscaleOnly) [ cfg.port ];

    # ── Operator helper script (wraps grdctl) ─────────────────────────────
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "ivali-remote-desktop" ''
        set -euo pipefail

        GRDCTL=${grd}/bin/grdctl
        SYSTEMCTL=${pkgs.systemd}/bin/systemctl

        usage() {
          cat <<'EOF'
        ivali-remote-desktop — IVALi Remote Desktop (RDP) helper

        Usage:
          ivali-remote-desktop status               Show backend + connection status
          ivali-remote-desktop enable               Enable the RDP backend (this user)
          ivali-remote-desktop disable              Disable the RDP backend (this user)
          ivali-remote-desktop set-port <port>      Override the RDP listen port
          ivali-remote-desktop enable-view-only     Remote clients cannot control input
          ivali-remote-desktop disable-view-only    Remote clients can control input
          ivali-remote-desktop credentials          Set username/password (keyring)
          ivali-remote-desktop certs                Print TLS certificate info
          ivali-remote-desktop daemon               Show GRD systemd user-unit status
          ivali-remote-desktop help                 Show this help
        EOF
        }

        require_session() {
          if [ -z "$XDG_RUNTIME_DIR" ] || [ ! -d "$XDG_RUNTIME_DIR" ]; then
            echo "error: not running in a graphical user session" >&2
            echo "run as the logged-in desktop user (ivali)" >&2
            exit 1
          fi
        }

        cmd_status() {
          require_session
          "$GRDCTL" status
        }

        cmd_enable() {
          require_session
          "$GRDCTL" rdp enable
          echo "RDP backend enabled. Set credentials once:"
          echo "  ivali-remote-desktop credentials"
        }

        cmd_disable() {
          require_session
          "$GRDCTL" rdp disable
          echo "RDP backend disabled."
        }

        cmd_credentials() {
          require_session
          "$GRDCTL" rdp set-credentials
          echo
          echo "RDP credentials stored in the GNOME keyring."
          echo "Remote clients connect with this username/password to:"
          echo "  tailscale-ip:${toString cfg.port}"
        }

        case "''${1:-help}" in
          status) cmd_status ;;
          enable) cmd_enable ;;
          disable) cmd_disable ;;
          set-port) "$GRDCTL" rdp set-port "''${2:?port required}" ;;
          enable-view-only) "$GRDCTL" rdp enable-view-only ;;
          disable-view-only) "$GRDCTL" rdp disable-view-only ;;
          credentials) cmd_credentials ;;
          certs) "$GRDCTL" status ;;
          daemon)
            "$SYSTEMCTL" --user status org.gnome.RemoteDesktop.User.service 2>&1 | head -n 8
            "$SYSTEMCTL" --user status org.gnome.RemoteDesktop.Headless.service 2>&1 | head -n 8
            ;;
          help|-h|--help) usage ;;
          *) usage ;;
        esac
      '')
    ];
  };
}
