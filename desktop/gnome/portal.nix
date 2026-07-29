##############################################################################
#
# Desktop GNOME XDG Desktop Portal
#
# Purpose
# -------
# Configure XDG Desktop Portals for screen sharing, audio capture, and
# file selection on Wayland. Required for browser screen/audio sharing
# (Google Meet, Discord, Slack screen share) and GTK portal integration.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Enable XDG portal with GNOME backend
# - Support screen capture and audio capture via PipeWire
# - GTK_USE_PORTAL=1 is set in gnome/default.nix session variables
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.desktop.gnome;
in
{
  config = lib.mkIf cfg.enable {
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
      config = {
        common.default = [ "gtk" ];
        gnome.default = [ "gnome" ];
      };
    };
  };
}
