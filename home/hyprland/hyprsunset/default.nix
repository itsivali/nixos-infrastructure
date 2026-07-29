{ config, lib, pkgs, hostSpec, ... }:

let
  theme = import ../themes { inherit hostSpec; };
in
{
  wayland.windowManager.hyprland.settings = {
    bind = [
      "SUPER ALT, T, exec, hyprsunset -t 3500 &"
      "SUPER ALT SHIFT, T, exec, pkill hyprsunset"
    ];
  };
}
