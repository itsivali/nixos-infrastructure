##############################################################################
#
# Theme — Dracula Preset
#
# Purpose
# -------
# Color palette and theme tokens for Dracula aesthetic.
#
##############################################################################

{
  name = "dracula";
  displayName = "Dracula";

  colors = {
    bg = "#282a36";
    bg1 = "#44475a";
    bg2 = "#6272a4";
    bg3 = "#44475a";
    fg = "#f8f8f2";
    fg1 = "#f8f8f2";
    fg2 = "#6272a4";
    red = "#ff5555";
    green = "#50fa7b";
    yellow = "#f1fa8c";
    blue = "#8be9fd";
    purple = "#bd93f9";
    aqua = "#8be9fd";
    orange = "#ffb86c";
    gray = "#6272a4";
    accent = "#bd93f9";
    activeBorder = "rgba(bd93f9ff) rgba(ff79c6ff) 45deg";
    inactiveBorder = "rgba(44475aaa)";
  };

  gtk = {
    theme = "adw-gtk3-dark";
    iconTheme = "Tela-dark";
    cursorTheme = "Bibata-Modern-Ice";
  };
}
