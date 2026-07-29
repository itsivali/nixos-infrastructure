##############################################################################
#
# Theme — Tokyo Night Preset
#
# Purpose
# -------
# Color palette and theme tokens for Tokyo Night aesthetic.
#
##############################################################################

{
  name = "tokyo-night";
  displayName = "Tokyo Night";

  colors = {
    bg = "#1a1b26";
    bg1 = "#24283b";
    bg2 = "#292e42";
    bg3 = "#414868";
    fg = "#a9b1d6";
    fg1 = "#c0caf5";
    fg2 = "#7aa2f7";
    red = "#f7768e";
    green = "#9ece6a";
    yellow = "#e0af68";
    blue = "#7aa2f7";
    purple = "#bb9af7";
    aqua = "#7dcfff";
    orange = "#ff9e64";
    gray = "#565f89";
    accent = "#7aa2f7";
    accentRgb = "rgb(7aa2f7)";
    activeBorder = "rgba(7aa2f7ff) rgba(bb9af7ff) 45deg";
    inactiveBorder = "rgba(292e42aa)";
  };

  gtk = {
    theme = "adw-gtk3-dark";
    iconTheme = "Tela-dark";
    cursorTheme = "Bibata-Modern-Ice";
  };
}
