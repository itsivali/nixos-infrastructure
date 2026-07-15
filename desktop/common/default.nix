##############################################################################
#
# Common Desktop — Shared Abstractions
#
# Purpose
# -------
# Provides shared desktop theming, colors, fonts, icons, and cursor
# configuration used by GNOME.
#
# Ownership
# ---------
# Color palette, GTK theming, font config, cursor theme, icon theme.
#
# Dependencies
# ------------
# None — pure option declarations with sensible defaults.
#
##############################################################################

{ ... }:

{
  imports = [
    ./colors.nix
  ];
}
