##############################################################################
#
# Theme — Mokka
#
# Purpose
# -------
# Aggregate view of the Catppuccin Mocha Mauve design system for GNOME/GTK.
# Single import point for the whole Mokka design system.
#
# Upstream source
# ---------------
# https://gitlab.com/garuda-linux/themes-and-settings/settings/garuda-mokka
#
# Design system
# -------------
# Based on Catppuccin Mocha Mauve:
#   Background:  30, 30, 46
#   Foreground: 205, 214, 244
#   Accent:     203, 166, 247 (Mauve)
#
# Ownership
# ---------
# theme.mokka
#
##############################################################################

let
  colors = import ./colors.nix;

  terminal = import ./terminal.nix {
    inherit (colors) terminal;
  };

  gtk = import ./gtk.nix;
in
{
  inherit colors terminal gtk;

  name = "mokka";
  displayName = "Mokka";

  description = "Catppuccin Mocha Mauve design system for GNOME/GTK";

  # GTK theme configuration (GTK3/GTK4)
  # Consumed by home/theming.nix for the GTK theme + icon theme + cursor
}
