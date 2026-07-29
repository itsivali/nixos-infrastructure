##############################################################################
#
# Desktop Hyprland System Packages
#
# Purpose
# -------
# System-level packages required for Hyprland desktop functionality,
# audio, screen lock, status bar, launchers, notifications, and screenshot tools.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.desktop.hyprland;
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # Core Hyprland utilities
      hyprland
      hyprlock
      hypridle
      hyprpaper

      # Desktop components
      waybar
      rofi
      swaynotificationcenter
      wlogout

      # Wayland utilities & helpers
      grim
      slurp
      swappy
      cliphist
      wl-clipboard
      brightnessctl
      pamixer
      playerctl
      polkit_gnome
      libnotify
      matugen
      imagemagick
      jq
      libva-utils
    ];
  };
}
