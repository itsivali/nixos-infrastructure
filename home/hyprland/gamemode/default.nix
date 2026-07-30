{ config, lib, pkgs, ... }:

{
  wayland.windowManager.hyprland.settings = {
    bind = [
      "SUPER ALT, G, exec, gamemoderun"
    ];
  };
}
