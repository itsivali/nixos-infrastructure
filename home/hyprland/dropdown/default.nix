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
    windowrule = [
      "float 1, match:title ^(Dropdown)$"
      "size 80% 50%, match:title ^(Dropdown)$"
      "move 10% 5%, match:title ^(Dropdown)$"
      "animation slide, match:title ^(Dropdown)$"
    ];

    bind = [
      "SUPER, grave, exec, konsole --profile Dropdown"
    ];
  };
}
