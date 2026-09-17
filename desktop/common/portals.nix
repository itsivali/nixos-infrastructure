##############################################################################
#
# Desktop — Common Portals
#
# Purpose
# -------
# XDG desktop portal integration shared by every desktop. GNOME session
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

      # GNOME portal backend provides screen sharing, screenshots, and
      # camera/microphone access through PipeWire on Wayland.
      extraPortals = [ pkgs.xdg-desktop-portal-gnome ];

      config.common = {
        # GTK-native file chooser for portal file dialogs (the GNOME backend
        # renders its own file dialog; the GTK override provides a GTK-native
        # file chooser for Electron/GTK apps).
        "org.freedesktop.impl.portal.FileChooser" = "gtk";
      };
    };
  };
}
