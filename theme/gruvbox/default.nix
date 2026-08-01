##############################################################################
#
# Theme — Gruvbox
#
# Purpose
# -------
# Aggregate view of the Gruvbox design system. Backwards-compatible with the
# former home/hyprland/themes/gruvbox.nix interface (colors/css/fonts/gtk/
# wallpaper), extended with per-consumer slices (qt, kvantum, konsole,
# waybar, hyprland, cursor, icons, ly, plymouth).
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
in
{
  inherit (palette) raw colors css toRgba toRgb toLy toLyBold;

  name = "gruvbox";
  displayName = "Gruvbox Dark";

  inherit cursor icons fonts;

  gtk = import ./gtk.nix { inherit cursor icons; };
  qt = import ./qt.nix { inherit (palette) colors; };
  kvantum = import ./kvantum.nix { inherit (palette) colors; };
  konsole = import ./konsole.nix { inherit (palette) colors; };
  kde = import ./kde.nix { inherit (palette) colors; };
  waybar = import ./waybar.nix { inherit (palette) colors css; };
  hyprland = import ./hyprland.nix { inherit (palette) colors; };
  ly = import ./ly.nix { inherit (palette) colors toLy toLyBold; };
  plymouth = import ./plymouth.nix { inherit (palette) colors; };
  wallpaper = import ./wallpaper.nix;
}
