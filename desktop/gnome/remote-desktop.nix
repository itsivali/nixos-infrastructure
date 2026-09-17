##############################################################################
#
# Desktop — GNOME Remote Desktop (GRD)
#
# Purpose
# -------
# System-level GNOME Remote Desktop configuration for the live GNOME session.
# RDP is exposed only on the Tailscale interface by default and uses the
# system user's PAM credentials.
#
# Ownership
# ---------
# ivali.desktop.remote-desktop, services.gnome.gnome-remote-desktop,
# networking.firewall
#
##############################################################################

{ config, lib, ... }:

let
  cfg = config.ivali.desktop.remote-desktop;
in
{
  options.ivali.desktop.remote-desktop = {
    enable = lib.mkEnableOption "GNOME Remote Desktop (RDP) over Tailscale";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3389;
      description = "TCP port the RDP server listens on.";
    };

    tailscaleOnly = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Restrict the RDP port to the Tailscale interface.";
    };
  };

  config = lib.mkIf (cfg.enable && (config.ivali.desktop.gnome.enable or false)) {
    services.gnome.gnome-remote-desktop.enable = true;

    networking.firewall.interfaces.tailscale0.allowedTCPPorts =
      lib.mkIf cfg.tailscaleOnly [ cfg.port ];
    networking.firewall.allowedTCPPorts = lib.mkIf (!cfg.tailscaleOnly) [ cfg.port ];
  };
}
