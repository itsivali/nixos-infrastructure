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
      "float 1, match:class ^(kitty-dropdown)$"
      "size 80% 50%, match:class ^(kitty-dropdown)$"
      "move 10% 5%, match:class ^(kitty-dropdown)$"
      "animation slide, match:class ^(kitty-dropdown)$"
    ];

    bind = [
      "SUPER, grave, exec, kitty --class kitty-dropdown"
    ];
  };
}
