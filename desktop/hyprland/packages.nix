##############################################################################
#
# Desktop — Hyprland System Packages
#
# Purpose
# -------
# System-level packages specific to the Hyprland desktop. Shared packages
# (grim, wl-clipboard, pavucontrol, ...) live in desktop/common/packages.nix.
#
# Ownership
# ---------
# ivali.desktop.hyprland
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.desktop.hyprland;
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # Core Hyprland + session tools
      hyprland
      hyprlock
      hypridle
      hyprpaper

      # Desktop components (bar, launcher, lockscreen, notifications)
      waybar
      rofi
      wlogout

      # Interactive status-bar tooling
      networkmanager_dmenu
      swayosd

      # Blue-light filter (SUPER ALT T) + gamemode (SUPER ALT G)
      hyprsunset
      gamemode

      # Bluetooth
      bluez
      bluez-tools
    ];
  };
}
