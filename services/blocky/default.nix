##############################################################################
#
# Services Blocky
#
# Purpose
# -------
# Barrel module for the Blocky DNS proxy/ad-blocker service.
# Auto-imports all files in this directory via lib/auto-imports.nix.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Auto-import Blocky service sub-modules
#
##############################################################################

{ ... }:

{
  imports = import ../../lib/auto-imports.nix ./.;
}
