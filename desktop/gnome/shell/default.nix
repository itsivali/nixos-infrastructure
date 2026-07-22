##############################################################################
#
# Desktop GNOME Shell
#
# Purpose
# -------
# Barrel module for GNOME Shell sub-modules (extensions).
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Import GNOME shell extension configuration
#
##############################################################################

{ ... }:

{
  imports = [
    ./extensions.nix
  ];
}
