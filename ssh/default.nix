##############################################################################
#
# SSH
#
# Purpose
# -------
# Barrel module for SSH service sub-modules. Auto-imports all files in this
# directory via lib/auto-imports.nix.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Auto-import SSH service sub-modules
#
##############################################################################

{ ... }:

{
  imports = import ../lib/auto-imports.nix ./.;
}
