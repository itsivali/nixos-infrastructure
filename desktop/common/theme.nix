##############################################################################
#
# Desktop — Common Theme
#
# Purpose
# -------
# Declares which design-system theme is active. Consumers (Plymouth, Ly,
# GTK, Qt) read this option instead of hard-coding a theme name.
#
# Ownership
# ---------
# ivali.desktop.common.theme
#
##############################################################################

{ lib, ... }:

{
  options.ivali.desktop.common.theme = {
    name = lib.mkOption {
      type = lib.types.str;
      default = "gruvbox";
      description = "Active desktop design-system theme";
    };
  };
}
