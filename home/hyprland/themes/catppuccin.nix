##############################################################################
#
# Theme — Catppuccin Mocha Preset
#
# Purpose
# -------
# Color palette and theme tokens for Catppuccin Mocha aesthetic.
#
##############################################################################

{
  name = "catppuccin";
  displayName = "Catppuccin Mocha";

  colors = {
    bg = "#1e1e2e";
    bg1 = "#181825";
    bg2 = "#313244";
    bg3 = "#45475a";
    fg = "#cdd6f4";
    fg1 = "#bac2de";
    fg2 = "#a6adc8";
    red = "#f38ba8";
    green = "#a6e3a1";
    yellow = "#f9e2af";
    blue = "#89b4fa";
    purple = "#cba6f7";
    aqua = "#94e2d5";
    orange = "#fab387";
    gray = "#585b70";
    accent = "#cba6f7";
    activeBorder = "rgba(cba6f7ff) rgba(89b4faff) 45deg";
    inactiveBorder = "rgba(313244aa)";
  };

  gtk = {
    theme = "adw-gtk3-dark";
    iconTheme = "Tela-dark";
    cursorTheme = "Bibata-Modern-Ice";
  };
}
