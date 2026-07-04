##############################################################################
#
# GNOME Shell Extensions
#
# Purpose
# -------
# Enable GNOME Shell extensions managed by the system.
#
# The DesktopControl extension is packaged by desktop/desktop-control.nix
# as a system package. This module enables it via dconf.
#
##############################################################################

{ config, lib, pkgs, ... }:

{
  dconf.settings = {
    "org/gnome/shell" = {
      enabled-extensions = [
        "desktop-control@prague.ivali"
      ];
    };
  };
}
