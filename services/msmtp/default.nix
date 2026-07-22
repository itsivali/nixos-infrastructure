##############################################################################
#
# Services msmtp
#
# Purpose
# -------
# Barrel module for msmtp mail transfer agent sub-modules. Auto-imports all
# files in this directory via lib/auto-imports.nix.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Auto-import msmtp service sub-modules
#
##############################################################################

{ ... }:

{
  imports = import ../../lib/auto-imports.nix ./.;
}
