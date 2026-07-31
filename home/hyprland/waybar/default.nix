##############################################################################
#
# Home — Waybar Desktop Module
#
# Purpose
# -------
# Waybar status bar Home Manager module. Defines the bar shell (layer,
# position, dimensions, module order) and merges in the per-module configs
# from ./modules with the theme CSS from ./style.nix.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
##############################################################################

{ config, lib, pkgs, hostSpec, ... }:

let
  theme = import ../themes;
  waybarModules = import ./modules;
in
{
  programs.waybar = {
    enable = true;
    systemd.enable = false;
    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 36;
      margin-top = 6;
      margin-left = 10;
      margin-right = 10;
      spacing = 4;

      modules-left = [
        "custom/appmenu"
        "hyprland/workspaces"
        "hyprland/window"
      ];

      modules-right = [
        "clock"
        "cpu"
        "memory"
        "custom/updates"
        "pulseaudio"
        "backlight"
        "network"
        "bluetooth"
        "battery"
        "idle_inhibitor"
        "custom/notification"
        "custom/power"
      ];
    } // waybarModules;

    style = import ./style.nix { inherit theme; };
  };
}
