{ config, lib, pkgs, hostSpec, ... }:

let
  theme = import ../themes { inherit hostSpec; };
in
{
  wayland.windowManager.hyprland.settings = {
    windowrulev2 = [
      "float, class:^(kitty-dropdown)$"
      "size 80% 50%, class:^(kitty-dropdown)$"
      "move 10% 5%, class:^(kitty-dropdown)$"
      "animation slide, class:^(kitty-dropdown)$"
    ];

    bind = [
      "SUPER, grave, exec, kitty --class kitty-dropdown"
    ];
  };
}
