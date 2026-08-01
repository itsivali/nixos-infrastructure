##############################################################################
#
# Desktop — Common Environment
#
# Purpose
# -------
# Wayland session environment variables shared by every desktop. Setting
# XDG_CURRENT_DESKTOP=Hyprland is what routes xdg-desktop-portal requests
# (screen sharing, file dialogs) to the Hyprland backend.
#
# Ownership
# ---------
# environment.sessionVariables
#
##############################################################################

{ config, lib, ... }:

{
  config = lib.mkIf (config.ivali.desktop.hyprland.enable or false) {
    environment.sessionVariables = {
      # Wayland-first applications
      NIXOS_OZONE_WL = "1";
      MOZ_ENABLE_WAYLAND = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "wayland";
      SDL_VIDEODRIVER = "wayland";
      CLUTTER_BACKEND = "wayland";
      _JAVA_AWT_WM_NONREPARENTING = "1";

      # Portal routing + GTK file dialogs through the portal
      XDG_CURRENT_DESKTOP = "Hyprland";
      XDG_SESSION_TYPE = "wayland";
      GTK_USE_PORTAL = "1";
    };
  };
}
