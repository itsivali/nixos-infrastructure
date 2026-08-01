##############################################################################
#
# Theme — Gruvbox Kvantum
#
# Purpose
# -------
# Kvantum theme colors for full Gruvbox Qt styling (Phase 3). Maps onto the
# [GeneralColors] section of a Kvantum theme, which overrides the colors
# baked into the theme SVG. Consumed by home/kde/kvantum.nix.
#
# Ownership
# ---------
# theme.gruvbox.kvantum
#
##############################################################################

{ colors }:

{
  window = colors.bg;
  base = colors.bg1;
  altBase = colors.bg2;
  button = colors.bg1;
  light = colors.bg2;
  midLight = colors.bg3;
  mid = colors.bg3;
  dark = colors.bgHard;

  text = colors.fg;
  windowText = colors.fg;
  buttonText = colors.fg;
  disabledText = colors.gray;
  tooltipText = colors.fg;
  progressText = colors.fg;

  highlight = colors.orange;
  inactiveHighlight = colors.gray;
  highlightedText = colors.bgHard;

  link = colors.blue;
  linkVisited = colors.purple;
}
