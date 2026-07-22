##############################################################################
#
# Packages User
#
# Purpose
# -------
# Provides the user-facing package set (CLI tools only) via Home Manager.
# Desktop apps are handled by packages/system instead.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Re-export CLI packages for Home Manager user profile consumption
#
##############################################################################

# User-facing packages — CLI tools only; desktop apps go in packages/system.
{ pkgs }:
import ../cli { inherit pkgs; }
