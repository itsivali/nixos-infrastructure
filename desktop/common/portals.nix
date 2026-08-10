##############################################################################
#
# Desktop — Common Portals
#
# Purpose
# -------
# XDG desktop portal integration shared by every Wayland desktop. The GNOME
# desktop manager module already wires up xdg-desktop-portal with the GNOME +
# GTK backends and ships the gnome-session portal configuration, so only the
# file-chooser routing override is declared here.
#
# Ownership
# ---------
# xdg.portal
#
##############################################################################

{ config, lib, pkgs, ... }:

{
  config = lib.mkIf (config.ivali.desktop.gnome.enable or false) {
    xdg.portal.config.common = {
      # GTK-native file chooser for portal file dialogs (the GNOME backend
      # would otherwise render its own Switcheroo dialog for non-GNOME apps).
      "org.freedesktop.impl.portal.FileChooser" = "gtk";
    };
  };
}
