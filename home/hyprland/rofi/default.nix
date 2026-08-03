##############################################################################
#
# Home — Rofi Application Launcher & Menus
#
# Purpose
# -------
# Hyde-inspired Rofi launcher, application picker, theme selector, clipboard menu,
# and power management menu.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  theme = import ../themes;
in
{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    font = "Inter 12";
    terminal = "kitty";

    extraConfig = {
      modi = "drun,run,filebrowser,window";
      show-icons = true;
      icon-theme = "Tela-dark";
      drun-display-format = "{name}";
      disable-history = false;
      sidebar-mode = false;
    };

    theme = let inherit (config.lib.formats.rasi) mkLiteral; in {
      "*" = {
        bg = mkLiteral theme.colors.bg;
        bg-alt = mkLiteral theme.colors.bg1;
        fg = mkLiteral theme.colors.fg;
        accent = mkLiteral theme.colors.accent;

        background-color = mkLiteral "transparent";
        text-color = mkLiteral theme.colors.fg;
        margin = 0;
        padding = 0;
        spacing = 0;
      };

      "window" = {
        location = mkLiteral "center";
        width = mkLiteral "600px";
        border-radius = mkLiteral "16px";
        border = mkLiteral "2px";
        border-color = mkLiteral theme.colors.accent;
        background-color = mkLiteral "${theme.css.bgA95}";
        padding = mkLiteral "16px";
      };

      "mainbox" = {
        children = map mkLiteral [ "inputbar" "listview" ];
      };

      "inputbar" = {
        children = map mkLiteral [ "entry" ];
        background-color = mkLiteral theme.colors.bg1;
        border-radius = mkLiteral "10px";
        padding = mkLiteral "12px";
        margin = mkLiteral "0 0 16px 0";
      };

      "entry" = {
        placeholder = "Search applications...";
        placeholder-color = mkLiteral theme.colors.gray;
      };

      "listview" = {
        columns = 1;
        lines = 8;
        spacing = mkLiteral "6px";
        fixed-height = true;
      };

      "element" = {
        padding = mkLiteral "10px";
        border-radius = mkLiteral "8px";
      };

      "element selected" = {
        background-color = mkLiteral theme.colors.bg2;
        text-color = mkLiteral theme.colors.accent;
      };

      "element-icon" = {
        size = mkLiteral "24px";
        margin = mkLiteral "0 12px 0 0";
      };

      "element-text" = {
        vertical-align = mkLiteral "0.5";
      };
    };
  };
}
