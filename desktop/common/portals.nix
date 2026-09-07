##############################################################################
#
# Desktop — Common Portals
#
# Purpose
# -------
# XDG desktop portal integration shared by every desktop. The desktop manager
# modules (GNOME, XFCE) wire up xdg-desktop-portal with their own backends;
# only the file-chooser routing override is declared here so that native
# (non-sandboxed) apps get a GTK-native file chooser regardless of the
# active desktop.
#
# Ownership
# ---------
# xdg.portal
#
##############################################################################

{ config, lib, pkgs, ... }:

{
  config = lib.mkIf (config.ivali.desktop.enable or false) {
    xdg.portal.config.common = {
      # GTK-native file chooser for portal file dialogs (the GNOME backend
      # would otherwise render its own Switcheroo dialog for non-GNOME apps).
      "org.freedesktop.impl.portal.FileChooser" = "gtk";
    };
  };
}
