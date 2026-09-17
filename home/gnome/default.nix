##############################################################################
#
# Home Manager — GNOME Composition Root
#
# Purpose
# -------
# Compose all GNOME-specific Home Manager modules.
# This file contains imports only. Only imported when
# ivali.desktop.gnome.enable = true (see home/default.nix).
#
##############################################################################

{ ... }:

{
  imports = [
    ./desktop.nix
    ./keyboard.nix
    ./webapps.nix
    ./remote-desktop.nix
    ./applications.nix
  ];
}
