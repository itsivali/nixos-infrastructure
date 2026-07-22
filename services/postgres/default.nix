##############################################################################
#
# Services PostgreSQL
#
# Purpose
# -------
# Barrel module for PostgreSQL database sub-modules. Auto-imports all files
# in this directory via lib/auto-imports.nix.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Auto-import PostgreSQL service sub-modules
#
##############################################################################

{ ... }:

{
  imports = import ../../lib/auto-imports.nix ./.;
}
