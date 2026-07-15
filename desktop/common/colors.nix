##############################################################################
#
# Common Desktop — Color Palette
#
# Purpose
# -------
# Central color palette shared across all desktop environments.
# Single source of truth for the Gruvbox Dark theme colors.
#
# Ownership
# ---------
# ivali.desktop.common.colors option set.
#
##############################################################################

{ lib, ... }:

let
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
    bgHard = "#1d2021";
    bgSoft = "#32302f";
  };
in
{
  options.ivali.desktop.common.colors = lib.mapAttrs
    (name: _:
      lib.mkOption {
        type = lib.types.str;
        default = colors.${name};
        description = "Gruvbox Dark color: ${name}";
      })
    colors;
}
