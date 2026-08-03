##############################################################################
#
# Desktop — Common Portals
#
# Purpose
# -------
# XDG desktop portal integration shared by every Wayland desktop: Hyprland
# backend (screen sharing, global shortcuts) plus GTK fallback (file dialogs).
# XDG_CURRENT_DESKTOP=Hyprland (from common/environment.nix) is what makes
# portal requests route to the Hyprland backend.
#
# Ownership
# ---------
# xdg.portal
#
##############################################################################

{ config, lib, pkgs, ... }:

{
  config = lib.mkIf (config.ivali.desktop.hyprland.enable or false) {
    xdg.portal = {
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-hyprland
        pkgs.xdg-desktop-portal-gtk
      ];
      config = {
        common = {
          "org.freedesktop.impl.portal.FileChooser" = "gtk";
        };
        hyprland.default = "hyprland;gtk";
      };
    };
  };
}
