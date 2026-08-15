##############################################################################
#
# Home — Terminal
#
# Purpose
# -------
# Barrel for terminal emulator configuration. GNOME Terminal is the sole
# terminal emulator; its Gruvbox theme is applied here.
#
# Ownership
# ---------
# ivali.terminal
#
##############################################################################

{ ... }:

{
  imports = [
    ./gnome-terminal.nix
  ];
}
