##############################################################################
#
# Theme — Gruvbox Dark Preset
#
# Purpose
# -------
# Color palette and theme tokens for Gruvbox Dark aesthetic.
#
##############################################################################

{
  name = "gruvbox";
  displayName = "Gruvbox Dark";

  colors = {
    bg = "#282828";
    bg1 = "#3c3836";
    bg2 = "#504945";
    bg3 = "#665c54";
    fg = "#ebdbb2";
    fg1 = "#d5c4a1";
    fg2 = "#bdae93";
    red = "#fb4934";
    green = "#b8bb26";
    yellow = "#fabd2f";
    blue = "#83a598";
    purple = "#d3869b";
    aqua = "#8ec07c";
    orange = "#fe8019";
    gray = "#928374";
    accent = "#fe8019";
    accentRgb = "rgb(fe8019)";
    activeBorder = "rgba(fe8019ff) rgba(fabd2fff) 45deg";
    inactiveBorder = "rgba(504945aa)";
  };

  gtk = {
    theme = "adw-gtk3-dark";
    iconTheme = "Tela-dark";
    cursorTheme = "Bibata-Modern-Ice";
  };
}
