{ config, lib, pkgs, hyde-configs, ... }:

let
  cfg = config.hydenix.hm;
in
{
  imports = [
    ./hyde-core.nix
    ./hyprland
    ./waybar.nix
    ./rofi.nix
    ./wlogout.nix
    ./shell.nix
    ./notifications.nix
    ./swww.nix
    ./screenshots.nix
    ./theme.nix
    ./gtk.nix
    ./qt.nix
  ];

  options.hydenix.hm = {
    enable = lib.mkEnableOption "HyDE home-manager module (Hyprland)";
  };

  config = lib.mkIf cfg.enable {
    home.stateVersion = "25.05";
    programs.home-manager.enable = true;
  };
}
