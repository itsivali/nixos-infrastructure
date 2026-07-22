##############################################################################
#
# Desktop GNOME Applications
#
# Purpose
# -------
# Barrel module that imports all GNOME application sub-modules (defaults, MIME).
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Import default application preferences and MIME type configurations
#
##############################################################################

{ ... }:

{
  imports = [
    ./defaults.nix
    ./mime.nix
  ];
}
