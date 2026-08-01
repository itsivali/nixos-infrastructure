##############################################################################
#
# Theme — Gruvbox Qt
#
# Purpose
# -------
# Qt6 style and color palette for qt6ct/Kvantum (Phase 3). Ensures every Qt
# application — including non-KDE ones like Telegram — renders in Gruvbox.
#
##############################################################################

{ colors }:

{
  style = "kvantum";
  palette = {
    window = colors.bg;
    windowText = colors.fg;
    base = colors.bg1;
    alternateBase = colors.bg2;
    toolTipBase = colors.bg1;
    toolTipText = colors.fg;
    text = colors.fg;
    button = colors.bg1;
    buttonText = colors.fg;
    brightText = colors.fg;
    highlight = colors.orange;
    highlightedText = colors.bgHard;
    link = colors.blue;
    linkVisited = colors.purple;
    placeholder = colors.gray;
  };
}
