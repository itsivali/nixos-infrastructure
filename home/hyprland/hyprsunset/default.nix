##############################################################################
#
# Default
#
# Purpose
# -------
# Auto-generated module description.
#
##############################################################################

{ config, lib, pkgs, ... }:

{
  wayland.windowManager.hyprland.settings = {
    bind = [
      "SUPER ALT, T, exec, hyprsunset -t 3500 &"
      "SUPER ALT SHIFT, T, exec, pkill hyprsunset"
    ];
  };
}
