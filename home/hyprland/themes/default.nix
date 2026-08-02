##############################################################################
#
# Themes
#
# Purpose
# -------
# Backwards-compatible barrel exposing the Gruvbox design system at its
# historical home/hyprland/themes/ path.
#
# The canonical theme definitions now live in theme/gruvbox/; this module only
# re-imports ./gruvbox.nix so existing consumers keep working.
#
##############################################################################

# Backwards-compatible shim. The design system now lives in theme/gruvbox.
import ./gruvbox.nix
