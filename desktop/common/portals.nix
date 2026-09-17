##############################################################################
#
# Desktop — Common Portals
#
# Purpose
# -------
# XDG desktop portal integration shared by every desktop. The GNOME session
# module enables the full portal stack; only the file-chooser routing
# override is declared here so that native (non-sandboxed) apps get a
# GTK-native file chooser regardless of the active desktop.
#
# Ownership
# ---------
# xdg.portal
#
##############################################################################

{ config, lib, pkgs, ... }:

{
  config = lib.mkIf (config.ivali.desktop.enable or false) {
    xdg.portal = {
      enable = true;

      # KDE portal backend provides screen sharing, screenshots, and
      # camera/microphone access through PipeWire on Wayland.
      extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];

      config.common = {
        # GTK-native file chooser for portal file dialogs (the KDE backend
        # renders its own file dialog; the GTK override provides a GTK-native
        # file chooser for Electron/GTK apps).
        "org.freedesktop.impl.portal.FileChooser" = "gtk";
      };
    };
  };
}
