##############################################################################
#
# Theme — Mokka
#
# Purpose
# -------
# Aggregate view of the Garuda Mokka design system for KDE Plasma 6.
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

  # KDE Global Theme name (look-and-feel package)
  lookAndFeel = "Mokka";

  # KDE Color Scheme name
  colorScheme = "Mokka";

  # KDE Plasma desktop theme
  plasmaTheme = "Mokka";

  # Kvantum theme (from nixpkgs: catppuccin-kvariant=mocha accent=mauve)
  kvantum = {
    package = "catppuccin-kvantum";
    variant = "mocha";
    accent = "mauve";
    themeName = "Catppuccin-Mocha-Mauve";
  };

  # Window decoration (Aurorae)
  windowDecoration = {
    library = "org.kde.kwin.aurorae.v2";
    theme = "__aurorae__svg__CatppuccinMocha-Classic";
  };

  # Splash screen
  splashScreen = "Catppuccin-Mocha-Mauve-splash";
}
