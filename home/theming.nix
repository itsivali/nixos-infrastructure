##############################################################################
#
# Home — Shared Desktop Theming
#
# Purpose
# -------
# GTK, font, cursor, and icon configuration shared across all desktops.
# Single source of truth for visual consistency.
#
# Ownership
# ---------
# gtk.font, gtk.theme, gtk.iconTheme, gtk.cursorTheme,
# home.sessionVariables (GTK_THEME, XCURSOR_*).
#
##############################################################################

{ config, lib, pkgs, ... }:

{
  gtk = {
    enable = true;

    font = {
      name = "Inter";
      size = 11;
    };

    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };

    iconTheme = {
      name = "Tela-dark";
      package = pkgs.tela-icon-theme;
    };

    cursorTheme = {
      name = "Bibata-Modern-Ice";
      package = pkgs.bibata-cursors;
    };
  };

  home.sessionVariables = {
    GTK_THEME = "adw-gtk3-dark";
    XCURSOR_THEME = "Bibata-Modern-Ice";
    XCURSOR_SIZE = "24";
  };
}
