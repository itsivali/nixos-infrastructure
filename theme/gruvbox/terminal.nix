##############################################################################
#
# Theme — Gruvbox Terminal
#
# Purpose
# -------
# Gruvbox terminal appearance slice: font, ANSI palette and background/foreground
# colors for the GNOME Terminal profile. Every color comes from theme/gruvbox/
# colors.nix so it cannot drift from the rest of the design system.
#
# Ownership
# ---------
# theme.gruvbox.terminal
#
# Responsibilities
# ----------------
# - Expose the terminal font (JetBrains Mono Nerd Font, size 12)
# - Expose the 16-color ANSI palette (from colors.terminalPalette)
# - Expose background / foreground / cursor colors
#
##############################################################################

{ colors, terminalPalette }:

{
  name = "gruvbox";
  displayName = "Gruvbox Dark";

  font = "JetBrainsMono Nerd Font";
  fontSize = 12;

  background = colors.bg;
  foreground = colors.fg;
  cursor = colors.orange;
  selectionBackground = colors.bg2;

  # 16-color ANSI palette (see colors.terminalPalette).
  palette = terminalPalette;
}
