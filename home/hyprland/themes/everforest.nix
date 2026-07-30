##############################################################################
#
# Theme — Everforest Preset
#
# Purpose
# -------
# Color palette and theme tokens for Everforest Dark aesthetic.
#
##############################################################################

{
  name = "everforest";
  displayName = "Everforest Dark";

  colors = {
    bg = "#2d353b";
    bg1 = "#343f44";
    bg2 = "#3d484d";
    bg3 = "#475258";
    fg = "#d3c6aa";
    fg1 = "#e6e2cc";
    fg2 = "#9da9a0";
    red = "#e67e80";
    green = "#a7c080";
    yellow = "#dbbc7f";
    blue = "#7fbbb3";
    purple = "#d699b6";
    aqua = "#83c092";
    orange = "#e69875";
    gray = "#859289";
    accent = "#a7c080";
    activeBorder = "rgba(a7c080ff) rgba(83c092ff) 45deg";
    inactiveBorder = "rgba(3d484daa)";
  };

  gtk = {
    theme = "adw-gtk3-dark";
    iconTheme = "Tela-dark";
    cursorTheme = "Bibata-Modern-Ice";
  };
}
