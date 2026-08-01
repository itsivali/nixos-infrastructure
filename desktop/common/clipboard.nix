##############################################################################
#
# Desktop — Common Clipboard
#
# Purpose
# -------
# System-wide Wayland clipboard utilities. History management (cliphist) is
# configured per desktop in home/hyprland/clipboard.
#
# Ownership
# ---------
# ivali.desktop.clipboard
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.desktop.clipboard;
in
{
  options.ivali.desktop.clipboard = {
    enable = lib.mkEnableOption "Wayland clipboard utilities";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.wl-clipboard ];
  };
}
