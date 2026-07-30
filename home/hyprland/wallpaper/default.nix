{ config, lib, pkgs, hostSpec, ... }:

let
  wallpaperDir = "${hostSpec.repoPath or "/home/ivali/nixos-infrastructure"}/wallpapers";
  switchScript = pkgs.writeShellScript "switch-wallpaper" ''
    WALL=$(ls ${wallpaperDir}/*.jpg ${wallpaperDir}/*.png 2>/dev/null | shuf -n1)
    if [ -n "$WALL" ]; then
      hyprctl hyprpaper preload "$WALL"
      hyprctl hyprpaper wallpaper ",$WALL"
    fi
  '';
in
{
  wayland.windowManager.hyprland.settings = {
    bind = [
      "SUPER ALT, Right, exec, ${switchScript}"
      "SUPER ALT, Left, exec, ${switchScript}"
    ];
  };
}
