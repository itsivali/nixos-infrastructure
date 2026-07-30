{ config, lib, pkgs, hostSpec, ... }:

let
  theme = import ../themes;
  wallpaperDir = "${hostSpec.repoPath or "/home/ivali/nixos-infrastructure"}/wallpapers";
in
{
  services.hyprpaper = {
    enable = true;
    settings = {
      preload = [ "${wallpaperDir}/${theme.wallpaper.filename}" ];
      wallpaper = [ ",${wallpaperDir}/${theme.wallpaper.filename}" ];
      splash = false;
      ipc = true;
    };
  };
}
