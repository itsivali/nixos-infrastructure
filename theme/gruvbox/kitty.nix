##############################################################################
#
# Theme — Gruvbox Kitty
#
# Purpose
# -------
# Kitty color scheme: background, foreground and the full 16-color ANSI
# palette (dark -> bright). Consumed by home/terminal/kitty.nix.
#
##############################################################################

{ colors }:

{
  background = colors.bg;
  foreground = colors.fg;
  palette = [
    colors.bg # color0  black
    colors.red # color1  red
    colors.green # color2  green
    colors.yellow # color3  yellow
    colors.blue # color4  blue
    colors.purple # color5  magenta
    colors.aqua # color6  cyan
    colors.fg1 # color7  white
    colors.gray # color8  bright black
    colors.red # color9  bright red
    colors.green # color10 bright green
    colors.yellow # color11 bright yellow
    colors.blue # color12 bright blue
    colors.purple # color13 bright magenta
    colors.aqua # color14 bright cyan
    colors.fg # color15 bright white
  ];
}
