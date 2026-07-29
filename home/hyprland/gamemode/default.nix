{ config, lib, pkgs, hostSpec, ... }:

let
  theme = import ../themes { inherit hostSpec; };
in
{
  wayland.windowManager.hyprland.settings = {
    bind = [
      "SUPER ALT, G, exec, gamemoderun"
    ];
  };
}
