{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.desktop.gnome;

  extensions = [
    pkgs.gnomeExtensions.blur-my-shell
    pkgs.gnomeExtensions.dash-to-dock
    pkgs.gnomeExtensions.user-themes
    pkgs.gnomeExtensions.caffeine
    pkgs.gnomeExtensions.clipboard-indicator
    pkgs.gnomeExtensions.vitals
    pkgs.gnomeExtensions.appindicator
    pkgs.gnomeExtensions.sound-output-device-chooser
    pkgs.gnomeExtensions.just-perfection
    pkgs.gnomeExtensions.places-status-indicator
    pkgs.gnomeExtensions.rounded-window-corners-reborn
    pkgs.gnomeExtensions.burn-my-windows
    pkgs.gnomeExtensions.search-light
    pkgs.gnomeExtensions.logo-menu
    pkgs.gnomeExtensions.bluetooth-quick-connect
    pkgs.gnomeExtensions.color-picker
    pkgs.gnomeExtensions.weather-oclock
    pkgs.gnomeExtensions.forge
    pkgs.gnomeExtensions.night-theme-switcher
    pkgs.gnomeExtensions.auto-move-windows
    pkgs.gnomeExtensions.workspace-indicator
    pkgs.gnomeExtensions.quick-settings-tweaker
    pkgs.gnomeExtensions.window-list
    pkgs.gnomeExtensions.focus-changer
  ];
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = extensions ++ [
      pkgs.gnome-tweaks
      pkgs.gnome-shell-extensions
      pkgs.glib
    ];
  };
}
