##############################################################################
#
# Home — KRunner Launcher
#
# Purpose
# -------
# KRunner (KDE Plasma application launcher / run dialog) replacing Rofi for
# application launching. Provides the Gruvbox KDE color scheme so Plasma
# surfaces render with the unified palette.
#
# Ownership
# ---------
# home.hyprland.krunner
#
# Responsibilities
# ----------------
# - Install KRunner (provided by plasma-workspace via desktop.kde)
# - Deploy the Gruvbox KDE color scheme to ~/.local/share/color-schemes/
# - Point Plasma at the Gruvbox color scheme via ~/.config/kdeglobals
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  theme = import ../themes;
  kde = theme.kde;
in
{
  home.file = {
    ".local/share/color-schemes/${kde.fileName}".text = kde.colorsFile;
    ".config/kdeglobals".text = ''
      [General]
      ColorScheme=${kde.schemeId}
    '';
  };
}
