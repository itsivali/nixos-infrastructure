##############################################################################
#
# Desktop GNOME Packages
#
# Purpose
# -------
# Installs the curated set of GNOME applications and utilities as system
# packages (Extension Manager, Loupe, Papers, Nautilus, etc.).
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Install GNOME applications (Extension Manager, Loupe, Console, Papers, etc.)
# - Install GNOME system utilities (Calendar, Clocks, Contacts, Weather, Maps)
# - Install xdg-utils and glib for desktop integration
#
##############################################################################

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
