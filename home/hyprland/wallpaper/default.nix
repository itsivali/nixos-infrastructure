{ config, lib, pkgs, hostSpec, ... }:

let
  theme = import ../themes { inherit hostSpec; };
  wallpaperDir = "${hostSpec.repoPath or "/home/ivali/nixos-infrastructure"}/wallpapers";
in
{
  wayland.windowManager.hyprland.settings = {
    bind = [
      "SUPER ALT, Right, exec, hyprctl hyprpaper reload $(ls ${wallpaperDir}/*.jpg ${wallpaperDir}/*.png 2>/dev/null | shuf -n1)"
      "SUPER ALT, Left, exec, hyprctl hyprpaper reload $(ls ${wallpaperDir}/*.jpg ${wallpaperDir}/*.png 2>/dev/null | shuf -n1)"
    ];
  };
}
