##############################################################################
#
# Desktop — Common Colors
#
# Purpose
# -------
# Exposes the Gruvbox palette as NixOS options for system-level consumers
# (e.g. Plymouth, Ly) that cannot import the pure theme data directly.
#
# Ownership
# ---------
# ivali.desktop.common.colors
#
##############################################################################

{ lib, ... }:

let
  gruvbox = import ../../theme/gruvbox/default.nix;
  colors = gruvbox.colors;
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
