{ config, lib, pkgs, hostSpec, ... }:

let
  wallpaperDir = "${hostSpec.repoPath or "/home/ivali/nixos-infrastructure"}/wallpapers";
in
{
  services.hyprpaper = {
    enable = true;
    settings = {
      preload = [ "${wallpaperDir}/default.jpg" ];
      wallpaper = [ ",${wallpaperDir}/default.jpg" ];
      splash = false;
      ipc = true;
    };
  };
}
