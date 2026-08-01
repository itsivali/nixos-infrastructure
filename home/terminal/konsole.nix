##############################################################################
#
# Home — Konsole Terminal
#
# Purpose
# -------
# Konsole (KDE Frameworks terminal) configured with the Gruvbox color
# scheme, MesloLGS NF font, and a default profile. Declaratively generates
# the .colorscheme, .profile and konsolerc files from the theme engine.
#
# Ownership
# ---------
# programs.konsole (via home.file), ivali.theme
#
# Responsibilities
# ----------------
# - Install Konsole
# - Write the Gruvbox color scheme (~/.local/share/konsole/Gruvbox.colorscheme)
# - Write the default profile (Gruvbox) + dropdown profile
# - Point konsolerc at the default profile
#
##############################################################################

{ config, lib, pkgs, hostSpec, ... }:

let
  theme = import ../../theme/gruvbox/default.nix;
  k = theme.konsole;

  palette = k.palette;
  # Konsole ANSI order: 0 black .. 7 white, then bright variants.
  colorOf = i:
    let
      c = builtins.elemAt palette i;
    in
    theme.toRgb c;

  colorscheme = ''
    [General]
    Description=Gruvbox Dark
    Opacity=0.95

    [Background]
    Color=${theme.toRgb k.background}

    [Background Faint]
    Color=${theme.toRgb k.background}

    [Background Intense]
    Color=${theme.toRgb k.background}

    [Foreground]
    Color=${theme.toRgb k.foreground}

    [Foreground Faint]
    Color=${theme.toRgb k.foreground}

    [Foreground Intense]
    Color=${theme.toRgb k.foreground}

    [Color0]
    Color=${colorOf 0}

    [Color0Intense]
    Color=${colorOf 8}

    [Color1]
    Color=${colorOf 1}

    [Color1Intense]
    Color=${colorOf 9}

    [Color2]
    Color=${colorOf 2}

    [Color2Intense]
    Color=${colorOf 10}

    [Color3]
    Color=${colorOf 3}

    [Color3Intense]
    Color=${colorOf 11}

    [Color4]
    Color=${colorOf 4}

    [Color4Intense]
    Color=${colorOf 12}

    [Color5]
    Color=${colorOf 5}

    [Color5Intense]
    Color=${colorOf 13}

    [Color6]
    Color=${colorOf 6}

    [Color6Intense]
    Color=${colorOf 14}

    [Color7]
    Color=${colorOf 7}

    [Color7Intense]
    Color=${colorOf 15}
  '';

  font = "${theme.fonts.monospace},${toString theme.fonts.size},50";

  profile = ''
    [General]
    Name=Gruvbox
    Parent=FALLBACK/
    ColorScheme=Gruvbox
    Font=${font}
    Opacity=0.95
    TerminalColumns=100
    TerminalRows=30
  '';

  dropdownProfile = ''
    [General]
    Name=Dropdown
    Parent=FALLBACK/
    ColorScheme=Gruvbox
    Font=${font}
    Opacity=0.95
    TerminalColumns=100
    TerminalRows=30
    tabtitle=Dropdown
    HideMenubar=true
    HideTabBar=true
  '';

  konsolerc = ''
    [Desktop Entry]
    DefaultProfile=Gruvbox.profile
  '';
in
{
  home.packages = [ pkgs.kdePackages.konsole ];

  home.file = {
    ".local/share/konsole/Gruvbox.colorscheme".text = colorscheme;
    ".local/share/konsole/Gruvbox.profile".text = profile;
    ".local/share/konsole/Dropdown.profile".text = dropdownProfile;
    ".config/konsolerc".text = konsolerc;
  };
}
