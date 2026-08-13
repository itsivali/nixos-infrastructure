##############################################################################
#
# Home — Terminal
#
# Purpose
# -------
# Barrel for terminal emulator configuration: Kitty (default terminal),
# plus the Mokka theme applied to GNOME Terminal.
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
    ./gnome-terminal.nix
  ];
}
