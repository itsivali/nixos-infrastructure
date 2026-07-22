##############################################################################
#
# Desktop GNOME Shell Extensions
#
# Purpose
# -------
# Installs the curated set of GNOME Shell extensions (Dash to Panel, Forge,
# Blur My Shell, Caffeine, etc.) and supporting packages.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Install curated GNOME extensions as system packages
# - Include gnome-tweaks, gnome-shell-extensions, and glib for extension support
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.desktop.gnome;

  # Curated, non-overlapping extension set.
  # - dash-to-panel replaces dash-to-dock + window-list (top-bar dock + taskbar)
  # - forge owns tiling; auto-move-windows removed (overlap)
  # - night-theme-switcher removed (static prefer-dark already set)
  extensions = [
    pkgs.gnomeExtensions.blur-my-shell
    pkgs.gnomeExtensions.dash-to-panel
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
    pkgs.gnomeExtensions.workspace-indicator
    pkgs.gnomeExtensions.quick-settings-tweaker
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
