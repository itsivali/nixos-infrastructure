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

  hyprTheme = import ./hyprland/themes;

  themeName = if hyprlandEnabled then hyprTheme.gtk.theme else "adw-gtk3-dark";
  themePkg = pkgs.adw-gtk3;
  iconName = if hyprlandEnabled then hyprTheme.gtk.iconTheme else "Tela-dark";
  iconPkg = pkgs.tela-icon-theme;
  cursorName = if hyprlandEnabled then hyprTheme.gtk.cursorTheme else "Bibata-Modern-Ice";
  cursorPkg = pkgs.bibata-cursors;
  fontName = if hyprlandEnabled then hyprTheme.fonts.sans else "Inter";
  fontSize = if hyprlandEnabled then hyprTheme.fonts.size else 11;
in
{
  gtk = {
    enable = true;

    font = {
      name = fontName;
      size = fontSize;
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

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  home.sessionVariables = {
    XCURSOR_THEME = cursorName;
    XCURSOR_SIZE = "24";
  };
}
