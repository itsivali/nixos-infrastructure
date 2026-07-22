##############################################################################
#
# Desktop GNOME Appearance
#
# Purpose
# -------
# Barrel module that imports all GNOME appearance sub-modules (colors, GTK,
# icons, cursor, fonts).
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Import colors, GTK, icons, cursor, and font appearance modules
#
##############################################################################

{ ... }:

{
  imports = [
    ./colors.nix
    ./gtk.nix
    ./icons.nix
    ./cursor.nix
    ./fonts.nix
  ];
}
