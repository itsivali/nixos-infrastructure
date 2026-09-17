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
  mokka = import ../../theme/mokka/colors.nix;
in
{
  options.ivali.desktop.common.colors = {
    background = lib.mkOption {
      type = lib.types.str;
      default = "30,30,46";
      description = "Mokka base background color (RGB)";
    };
    foreground = lib.mkOption {
      type = lib.types.str;
      default = "205,214,244";
      description = "Mokka base foreground color (RGB)";
    };
    accent = lib.mkOption {
      type = lib.types.str;
      default = "203,166,247";
      description = "Mokka Mauve accent color (RGB)";
    };
  };
}
