##############################################################################
#
# Home — Shared Desktop Theming
#
# Purpose
# -------
# GTK, font, cursor, and icon configuration shared across all desktops.
# When Hyprland is active, GTK settings follow the selected theme preset.
# Falls back to adw-gtk3-dark when only GNOME is used.
#
# Ownership
# ---------
# gtk.font, gtk.theme, gtk.iconTheme, gtk.cursorTheme,
# home.sessionVariables (GTK_THEME, XCURSOR_*).
#
##############################################################################

{ config, lib, pkgs, hostSpec, ... }:

let
  hostConfig = hostSpec.config or { };
  hyprlandEnabled = hostConfig.ivali.desktop.hyprland.enable or false;

  hyprTheme = import ./hyprland/themes { inherit hostSpec; };

  themeName = if hyprlandEnabled then hyprTheme.gtk.theme else "adw-gtk3-dark";
  themePkg = pkgs.adw-gtk3;
  iconName = if hyprlandEnabled then hyprTheme.gtk.iconTheme else "Tela-dark";
  iconPkg = pkgs.tela-icon-theme;
  cursorName = if hyprlandEnabled then hyprTheme.gtk.cursorTheme else "Bibata-Modern-Ice";
  cursorPkg = pkgs.bibata-cursors;
in
{
  gtk = {
    enable = true;

    font = {
      name = "Inter";
      size = 11;
    };

    theme = {
      name = themeName;
      package = themePkg;
    };

    iconTheme = {
      name = iconName;
      package = iconPkg;
    };

    cursorTheme = {
      name = cursorName;
      package = cursorPkg;
    };
  };

  home.sessionVariables = {
    GTK_THEME = themeName;
    XCURSOR_THEME = cursorName;
    XCURSOR_SIZE = "24";
  };
}
