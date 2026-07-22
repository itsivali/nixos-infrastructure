##############################################################################
#
# Desktop
#
# Purpose
# -------
# Domain entry-point for desktop environment modules. Auto-imports all
# sub-modules via lib/auto-imports.nix.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Serve as the barrel module for the desktop domain
# - Auto-import all *.nix files in this directory tree
#
##############################################################################

{ ... }:
{
  imports = import ../lib/auto-imports.nix ./.;
}
