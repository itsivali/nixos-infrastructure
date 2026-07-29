##############################################################################
#
# Desktop Hyprland XDG Desktop Portal
#
# Purpose
# -------
# Configures XDG desktop portal integration for Hyprland screen sharing,
# file selection dialogs, and desktop interactions.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.desktop.hyprland;
in
{
  config = lib.mkIf cfg.enable {
    xdg.portal = {
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-hyprland
        pkgs.xdg-desktop-portal-gtk
      ];
      config = {
        hyprland.default = [ "hyprland" "gtk" ];
      };
    };
  };
}
