{ config, lib, pkgs, ... }:

let
  cfg = config.hydenix;
in
{
  config = lib.mkIf cfg.enable {
    programs.hyprland = {
      enable = true;
      package = pkgs.hyprland;
      withUWSM = true;
    };

    environment.systemPackages = with pkgs; [
      # HyDE core
      hyprland
      hyprlock
      hypridle
      hyprcursor
      hyprpicker
      hyprland-contrib.hyprctl
      xdg-desktop-portal-hyprland

      # Desktop environment
      waybar
      rofi-wayland
      wlogout
      swww
      dunst
      libnotify

      # Utilities
      grim
      slurp
      wl-clipboard
      brightnessctl
      networkmanagerapplet
      pavucontrol
      pamixer
      playerctl

      # File management
      kdePackages.dolphin
      ark
      kdePackages.ffmpegthumbs
      kdePackages.kde-cli-tools
      libsForQt5.qtimageformats

      # Theme support
      bibata-cursors
      tela-circle-icon-theme
      noto-fonts-color-emoji
      xdg-user-dirs
    ];
  };
}
