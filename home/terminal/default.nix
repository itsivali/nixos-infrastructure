##############################################################################
#
# Home — Terminal
#
# Purpose
# -------
# Barrel for terminal emulator configuration. Currently hosts Kitty
# (default terminal with the Gruvbox design system).
#
# Ownership
# ---------
# ivali.terminal
#
##############################################################################

{ ... }:

{
  imports = [
    ./kitty.nix
  ];
}
