##############################################################################
#
# Theme — Gruvbox Waybar
#
# Purpose
# -------
# Waybar CSS surfaces derived from the palette. Consumed by
# home/hyprland/waybar/style.nix.
#
##############################################################################

{ colors, css }:

{
  inherit (css) bgA65 bgA85 bgA95;
  background = css.bgA65;
  surface = colors.bg1;
  surfaceAlt = colors.bg2;
  border = colors.bg3;
  text = colors.fg;
  textAlt = colors.fg1;
  textMuted = colors.gray;
  accent = colors.orange;
  red = colors.red;
  green = colors.green;
  yellow = colors.yellow;
  blue = colors.blue;
  purple = colors.purple;
  aqua = colors.aqua;
}
