##############################################################################
#
# Theme — Gruvbox
#
# Purpose
# -------
# Aggregate view of the Gruvbox design system. Backwards-compatible with the
# former home/hyprland/themes/gruvbox.nix interface (colors/css/fonts/gtk/
# wallpaper), extended with per-consumer slices (qt, kitty, cursor, icons,
# plymouth).
#
# Ownership
# ---------
# theme.gruvbox
#
# Responsibilities
# ----------------
# - Single import point for the whole design system
# - One source of truth for every color value in the repository
#
##############################################################################

let
  palette = import ./colors.nix;

  cursor = import ./cursor.nix;
  icons = import ./icons.nix;
  fonts = import ./fonts.nix;

  # Qt style for GNOME platform theme (single style source for Qt surfaces).
  qt = import ./qt.nix;

  # Garuda-terminal look (Mokka / Catppuccin Mocha) for the Kitty emulator.
  mokka = import ./mokka.nix;
in
{
  inherit (palette) raw colors css toRgba toRgb toLy toLyBold;

  name = "gruvbox";
  displayName = "Gruvbox Dark";

  inherit cursor icons fonts qt mokka;

  gtk = import ./gtk.nix { inherit cursor icons; };
  plymouth = import ./plymouth.nix { inherit (palette) colors; };
}
