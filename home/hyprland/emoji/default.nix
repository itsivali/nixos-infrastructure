{ config, lib, pkgs, ... }:

{
  wayland.windowManager.hyprland.settings = {
    bind = [
      "SUPER, period, exec, rofi -show emoji"
    ];
  };
}
