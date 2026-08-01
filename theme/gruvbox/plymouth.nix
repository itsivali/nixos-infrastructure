##############################################################################
#
# Theme — Gruvbox Plymouth
#
# Purpose
# -------
# Plymouth boot-splash colors (background/foreground/accent). Consumed by
# boot/plymouth.nix.
#
##############################################################################

{ colors }:

{
  background = colors.bg;
  foreground = colors.fg;
  accent = colors.orange;
}
