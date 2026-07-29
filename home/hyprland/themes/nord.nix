##############################################################################
#
# Theme — Nord Preset
#
# Purpose
# -------
# Color palette and theme tokens for Nord aesthetic.
#
##############################################################################

{
  name = "nord";
  displayName = "Nord Dark";

  colors = {
    bg = "#2e3440";
    bg1 = "#3b4252";
    bg2 = "#434c5e";
    bg3 = "#4c566a";
    fg = "#eceff4";
    fg1 = "#e5e9f0";
    fg2 = "#d8dee9";
    red = "#bf616a";
    green = "#a3be8c";
    yellow = "#ebcb8b";
    blue = "#81a1c1";
    purple = "#b48ead";
    aqua = "#88c0d0";
    orange = "#d08770";
    gray = "#616e88";
    accent = "#88c0d0";
    accentRgb = "rgb(88c0d0)";
    activeBorder = "rgba(88c0d0ff) rgba(81a1c1ff) 45deg";
    inactiveBorder = "rgba(434c5eaa)";
  };

  gtk = {
    theme = "adw-gtk3-dark";
    iconTheme = "Tela-dark";
    cursorTheme = "Bibata-Modern-Ice";
  };
}
