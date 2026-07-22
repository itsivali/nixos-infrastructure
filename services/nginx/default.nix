##############################################################################
#
# Services Nginx
#
# Purpose
# -------
# Barrel module for Nginx web server sub-modules. Auto-imports all files
# in this directory via lib/auto-imports.nix.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Auto-import Nginx service sub-modules
#
##############################################################################

{ ... }:

{
  imports = import ../../lib/auto-imports.nix ./.;
}
