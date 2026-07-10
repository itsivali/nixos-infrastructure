{ config, lib, pkgs, ... }:

{
  config = lib.mkIf config.ivali.desktop.gnome.enable {
    environment.systemPackages = with pkgs; [
      # GNOME desktop tools
      gnome-tweaks
      gnome-shell-extensions
      gnome-browser-connector

      # Essential GNOME Shell extensions
      gnomeExtensions.appindicator
      gnomeExtensions.dash-to-dock
      gnomeExtensions.blur-my-shell
      gnomeExtensions.user-themes
      gnomeExtensions.caffeine
      gnomeExtensions.clipboard-indicator
      gnomeExtensions.vitals
      gnomeExtensions.sound-output-device-chooser

      # Utilities for D-Bus and gsettings
      glib
    ];
  };
}
