##############################################################################
#
# Gruvbox
#
# Purpose
# -------
# Backwards-compatible shim exposing the Gruvbox design system at its
# historical home/hyprland/themes/gruvbox.nix path.
#
# The canonical theme definitions now live in theme/gruvbox/; this module only
# re-imports theme/gruvbox/default.nix so existing consumers keep working.
#
##############################################################################

# Backwards-compatible shim. The design system now lives in theme/gruvbox.
import ../../../theme/gruvbox/default.nix
