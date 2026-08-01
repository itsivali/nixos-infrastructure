##############################################################################
#
# Theme — Gruvbox Ly
#
# Purpose
# -------
# Ly display manager true-color styling (0xSSRRGGBB format, SS = style bits).
# Consumed by desktop/login/ly.nix.
#
##############################################################################

{ colors, toLy, toLyBold }:

{
  bg = toLy colors.bg;
  fg = toLy colors.fg;
  border_fg = toLy colors.orange;
  error_fg = toLyBold colors.red;
  colormix_col1 = toLy colors.orange;
  colormix_col2 = toLy colors.purple;
  colormix_col3 = toLy colors.green;
}
