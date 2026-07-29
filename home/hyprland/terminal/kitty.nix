##############################################################################
#
# Home — Kitty Terminal Configuration
#
# Purpose
# -------
# GPU-accelerated Kitty terminal configured with Hyde theme colors, font options,
# opacity, and padding.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
##############################################################################

{ config, lib, pkgs, hostSpec, ... }:

let
  theme = import ../themes { inherit hostSpec; };
in
{
  programs.kitty = {
    enable = true;
    font = {
      name = "MesloLGS NF";
      size = 11;
    };
    settings = {
      window_padding_width = 12;
      background_opacity = "0.95";
      confirm_os_window_close = 0;

      background = theme.colors.bg;
      foreground = theme.colors.fg;

      color0 = theme.colors.bg;
      color8 = theme.colors.gray;

      color1 = theme.colors.red;
      color9 = theme.colors.red;

      color2 = theme.colors.green;
      color10 = theme.colors.green;

      color3 = theme.colors.yellow;
      color11 = theme.colors.yellow;

      color4 = theme.colors.blue;
      color12 = theme.colors.blue;

      color5 = theme.colors.purple;
      color13 = theme.colors.purple;

      color6 = theme.colors.aqua;
      color14 = theme.colors.aqua;

      color7 = theme.colors.fg1;
      color15 = theme.colors.fg;
    };
  };
}
