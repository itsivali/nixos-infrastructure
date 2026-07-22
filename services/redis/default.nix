##############################################################################
#
# Services Redis
#
# Purpose
# -------
# Barrel module for Redis key-value store sub-modules. Auto-imports all files
# in this directory via lib/auto-imports.nix.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Auto-import Redis service sub-modules
#
##############################################################################

{ ... }:

{
  imports = import ../../lib/auto-imports.nix ./.;
}
