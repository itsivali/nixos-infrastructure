##############################################################################
#
# Home — Terminal
#
# Purpose
# -------
# Barrel for terminal emulator configuration: Kitty (default terminal),
# plus the Mokka theme applied to GNOME Terminal and Konsole.
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
    ./mokka.nix
  ];
}
