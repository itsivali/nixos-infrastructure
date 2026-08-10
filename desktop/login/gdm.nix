##############################################################################
#
# Desktop — Login (GDM)
#
# Purpose
# -------
# GDM login manager for the GNOME desktop. Replaces Ly entirely. Runs the
# Wayland greeter by default (GNOME 50 is Wayland-only) and themes the login
# screen with the Gruvbox wallpaper + orange accent.
#
# Ownership
# ---------
# services.displayManager.gdm, programs.dconf.profiles.gdm
#
# Responsibilities
# ----------------
# - Present the GNOME greeter on the Wayland session
# - Launch the GNOME session (defaultSession = "gnome")
# - Theme the login screen: Gruvbox wallpaper, solid dark background,
#   dark color scheme and orange accent color
#
# Notes
# -----
# - GDM is not auto-enabled by the GNOME desktop manager module; it is
#   enabled here explicitly.
# - The greeter wallpaper is applied through a dedicated `gdm` dconf profile
#   (programs.dconf.profiles.gdm.databases), not the per-user dconf DB.
#
##############################################################################

{ config, lib, pkgs, ... }:

{
  config = lib.mkIf (config.ivali.desktop.gnome.enable or false) {
    services.displayManager.gdm.enable = true;

    # Boot straight into the GNOME session.
    services.displayManager.defaultSession = "gnome";

    # ── Gruvbox login screen ────────────────────────────────────────────
    # The greeter reads org/gnome/desktop/background for its wallpaper and
    # org/gnome/desktop/interface for the dark scheme + accent color.
    programs.dconf.profiles.gdm.databases = [
      {
        settings."org/gnome/desktop/background" = {
          picture-uri = "file://${../../wallpapers/default.jpg}";
          picture-uri-dark = "file://${../../wallpapers/default.jpg}";
          primary-color = "#282828";
          color-shading-type = "solid";
        };
        settings."org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
          accent-color = "orange";
        };
      }
    ];

    # PAM keyring support for the login session (GDM unlocks the keyring
    # automatically when enabled; keeps the service explicit).
    services.gnome.gnome-keyring.enable = lib.mkDefault true;
  };
}
