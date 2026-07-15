{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.desktop.gnome;
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      extension-manager
      loupe
      console
      gnome-text-editor
      papers
      file-roller
      mission-center
      resources
      gnome-tweaks
      impression
      warehouse
      decibels
      dconf-editor
      nautilus
      gnome-calendar
      gnome-clocks
      gnome-contacts
      gnome-weather
      gnome-maps
      gnome-screenshot
      xdg-utils
      glib
    ];
  };
}
