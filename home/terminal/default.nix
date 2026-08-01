##############################################################################
#
# Home — Terminal
#
# Purpose
# -------
# Barrel for terminal emulator configuration. Currently hosts Konsole
# (KDE Frameworks terminal with the Gruvbox design system).
#
# Ownership
# ---------
# ivali.terminal
#
##############################################################################

{ ... }:

{
  imports = [
    ./konsole.nix
  ];
}
