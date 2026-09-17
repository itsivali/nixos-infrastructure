##############################################################################
#
# Desktop — Remote Desktop (KDE KRDP / RDP)
#
# Purpose
# -------
# Remote desktop access to the live KDE Plasma session via Microsoft Remote
# Desktop Protocol (RDP) using the KDE KRDP server (krdp). Provides:
#
#   * KRDP server package (krdp)
#   * RDP backend on the Tailscale network only (by default)
#   * Per-user declarative enablement + TLS certificate bootstrap
#     (home/kde/remote-desktop.nix)
#
# Security model
# --------------
# * RDP port is opened ONLY on the `tailscale0` interface — the same
#   pattern used for SSH (see ssh/daemon.nix) and the previous GRD setup.
#   The port stays closed on the public internet.
# * Authentication uses KRDP system-user auth (SystemUserEnabled): remote
#   clients authenticate with the OS account credentials via PAM. No
#   password is stored in KWallet or in plaintext config — the login
#   password is the RDP password.
# * TLS uses a self-signed certificate generated (and self-healed) by the
#   user-session bootstrap at ~/.local/share/krdpserver/. The CN and SAN
#   track the Tailscale hostname, so the cert survives tailnet IP changes.
#   Self-signed certs are expected for RDP over an encrypted Tailscale
#   overlay; clients present a one-time trust prompt.
#
# Ownership
# ---------
# networking.firewall, environment.systemPackages, services.* (via
# grid_manager units in home/kde/remote-desktop.nix)
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.desktop.remote-desktop;
in
{
  options.ivali.desktop.remote-desktop = {
    enable = lib.mkEnableOption ''
      KDE KRDP remote desktop (RDP) access over Tailscale.

      Enables the KRDP server and opens the RDP port on the tailscale0
      interface only. The per-user backend (TLS cert + systemd unit) is
      wired by home/kde/remote-desktop.nix when the user account has the
      KDE desktop enabled.
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
    # ── KRDP server (KDE Plasma remote desktop) ─────────────────────────
    environment.systemPackages = [ pkgs.kdePackages.krdp ];

    # ── Firewall: RDP on Tailscale only (mirrors ssh/daemon.nix) ────────
    networking.firewall.interfaces.tailscale0.allowedTCPPorts =
      lib.mkIf cfg.tailscaleOnly [ cfg.port ];
    networking.firewall.allowedTCPPorts = lib.mkIf (!cfg.tailscaleOnly) [ cfg.port ];
  };
}
