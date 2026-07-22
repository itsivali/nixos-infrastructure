##############################################################################
#
# GNOME Desktop Launchers
#
# Purpose
# -------
# XDG desktop entries for custom tools so they appear in the GNOME
# application menu and can be pinned to the dock.
#
# Ownership
# ---------
# xdg.desktopEntries.*
#
##############################################################################

{ config, lib, pkgs, inputs, ... }:

let
  antigravityPkgs = inputs.antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  xdg.desktopEntries = {
    ivali-dashboard = {
      name = "ivali Control Plane";
      comment = "NixOS infrastructure control plane dashboard";
      exec = "ivali dashboard";
      icon = "utilities-terminal";
      terminal = false;
      categories = [ "System" "Utility" ];
      mimeType = [ ];
    };

    bw-tui = {
      name = "Bitwarden TUI";
      comment = "Bitwarden vault terminal interface";
      exec = "bw-tui";
      icon = "utilities-terminal";
      terminal = true;
      categories = [ "Security" "Utility" ];
      mimeType = [ ];
    };

    grafana = {
      name = "Observability Dashboard";
      comment = "Grafana monitoring dashboard";
      exec = "firefox http://localhost:3000/grafana/";
      icon = "utilities-system-monitor";
      terminal = false;
      categories = [ "System" "Monitor" ];
      mimeType = [ ];
    };

    tailscale-manager = {
      name = "Tailscale Manager";
      comment = "Tailscale VPN status and management";
      exec = "tailscale status";
      icon = "network-vpn";
      terminal = true;
      categories = [ "Network" "System" ];
      mimeType = [ ];
    };

    jules-ai = {
      name = "Jules AI Agent";
      comment = "Google Jules AI coding agent";
      exec = "jules";
      icon = "utilities-terminal";
      terminal = true;
      categories = [ "Development" "Utility" ];
      mimeType = [ ];
    };
  };
}
