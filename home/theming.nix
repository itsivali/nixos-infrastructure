##############################################################################
#
# Home — Shared Desktop Theming
#
# Purpose
# -------
# GTK, font, cursor, and icon configuration shared across all desktops.
# Always follows the Mokka design system (single source of truth in
# theme/mokka), and drives the GTK theme + accent color so GTK4
# and libadwaita apps render in Mokka.
#
# Ownership
# ---------
# gtk.font, gtk.theme, gtk.iconTheme, gtk.cursorTheme,
# dconf.settings."org/gnome/desktop/interface",
# home.sessionVariables (XCURSOR_*).
#
##############################################################################

{ config, lib, pkgs, ... }:

{
  gtk = {
    enable = true;

    font = {
      name = "Inter";
      size = 10;
    };

    theme = {
      name = "Catppuccin-Mocha-Standard-Mauve-Dark";
      package = pkgs.catppuccin-gtk.override {
        variant = "mocha";
        accents = [ "mauve" ];
        size = "standard";
      };
    };

    iconTheme = {
      name = "Tela-circle-dracula-dark";
      package = pkgs.tela-icon-theme;
    };

    cursorTheme = {
      name = "Catppuccin-Mocha-Mauve-Cursors";
      package = pkgs.catppuccin-cursors.mochaMauve;
    };

    gtk3.extraConfig = {
      "gtk-application-prefer-dark-theme" = 1;
    };

    gtk4.extraConfig = {
      "gtk-theme-name" = "Catppuccin-Mocha-Standard-Mauve-Dark";
    };
  };

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    accent-color = "mauve";
    font-antialiasing = "rgba";
    font-hinting = "full";
    cursor-size = 24;
  };

  home.sessionVariables = {
    XCURSOR_THEME = "Catppuccin-Mocha-Mauve-Cursors";
    XCURSOR_SIZE = "24";
  };
}
