##############################################################################
#
# Desktop GNOME Appearance Colors
#
# Purpose
# -------
# Provides the GNOME color palette by delegating to the shared common colors
# module. Exists for structural consistency with the gnome/appearance layout.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Maintain GNOME appearance directory structure for color palette
# - Reference desktop/common/colors.nix as the source of truth
#
##############################################################################

{ ... }:

{
  # Colors are provided by desktop/common/colors.nix (auto-imported).
  # This file exists for structural consistency with the gnome/appearance layout.
}
