##############################################################################
#
# Home — Shared Desktop Theming
#
# Purpose
# -------
# GTK, font, cursor, and icon configuration shared across all desktops.
# Always follows the Gruvbox design system (single source of truth in
# theme/gruvbox), and drives the GNOME color scheme + accent color so GTK4
# and libadwaita apps (the GNOME 50 default) render in Gruvbox.
#
# Ownership
# ---------
# gtk.font, gtk.theme, gtk.iconTheme, gtk.cursorTheme,
# dconf.settings."org/gnome/desktop/interface",
# home.sessionVariables (XCURSOR_*).
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  theme = import ../theme/gruvbox;
in
{
  gtk = {
    enable = true;

    font = {
      name = theme.fonts.sans;
      size = theme.fonts.size;
    };

    theme = {
      name = theme.gtk.theme;
      package = pkgs.adw-gtk3;
    };

    iconTheme = {
      name = theme.gtk.iconTheme;
      package = pkgs.tela-icon-theme;
    };

    cursorTheme = {
      name = theme.gtk.cursorTheme;
      package = pkgs.bibata-cursors;
    };

    gtk3.extraConfig = {
      "gtk-application-prefer-dark-theme" = 1;
    };

    gtk4.extraConfig = {
      "gtk-theme-name" = theme.gtk.theme;
    };
  };

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    accent-color = "orange";

    # Subpixel antialiasing + full hinting for crisp text (matches the
    # fontconfig defaults configured for the desktop).
    font-antialiasing = "rgba";
    font-hinting = "full";

    # Match the XCURSOR_SIZE session variable (28px, accessibility).
    cursor-size = theme.gtk.cursorSize;
  };

  home.sessionVariables = {
    XCURSOR_THEME = theme.gtk.cursorTheme;
    XCURSOR_SIZE = toString theme.gtk.cursorSize;
  };
}
