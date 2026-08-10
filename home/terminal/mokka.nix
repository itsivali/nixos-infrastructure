##############################################################################
#
# Home — Mokka Terminal Theming (GNOME Terminal + Konsole)
#
# Purpose
# -------
# Applies the Garuda "Mokka" look (Catppuccin-Mocha palette,
# JetBrainsMono Nerd Font, red block cursor, 90% opacity) to every
# terminal emulator that may be opened on the desktop:
#
#   - Kitty            → see ./kitty.nix (the default terminal)
#   - GNOME Terminal   → dconf profile ("Mokka", default profile)
#   - Konsole          → Konsole profile + Mokka.colorscheme (default)
#
# The single source of truth for every color is theme/gruvbox/mokka.nix;
# both terminal formats are generated from that slice so they cannot drift.
#
# Ownership
# ---------
# programs.kitty (./kitty.nix), dconf (GNOME Terminal), home.file (Konsole)
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  theme = import ../../theme/gruvbox/default.nix;
  m = theme.mokka;

  # Konsole .colorscheme uses "R,G,B" triplets — convert from hex so the
  # scheme is generated from theme/gruvbox/mokka.nix.
  hexDigit = d: {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    a = 10;
    b = 11;
    c = 12;
    d = 13;
    e = 14;
    f = 15;
  }.${d};

  hexByte = s: hexDigit (builtins.substring 0 1 s) * 16 + hexDigit (builtins.substring 1 1 s);

  toRGB = hex:
    let
      r = hexByte (builtins.substring 1 2 hex);
      g = hexByte (builtins.substring 3 2 hex);
      b = hexByte (builtins.substring 5 2 hex);
    in
    "${toString r},${toString g},${toString b}";

  # Konsole .colorscheme — structurally identical to the stock Garuda
  # /usr/share/konsole/Mokka.colorscheme, generated from the mokka slice.
  konsoleColorscheme = with m; (lib.concatStringsSep "\n" ([
    "[Background]"
    "Color=${toRGB background}"
    ""
    "[BackgroundFaint]"
    "Color=${toRGB background}"
    ""
    "[BackgroundIntense]"
    "Color=${toRGB background}"
    ""
  ] ++ lib.flatten (lib.imap0
    (i: c: [
      "[Color${toString i}]"
      "Color=${toRGB c}"
      ""
      "[Color${toString i}Faint]"
      "Color=${toRGB c}"
      ""
      "[Color${toString i}Intense]"
      "Color=${toRGB c}"
      ""
    ])
    palette) ++ [
    "[Foreground]"
    "Color=${toRGB foreground}"
    ""
    "[ForegroundFaint]"
    "Color=${toRGB foreground}"
    ""
    "[ForegroundIntense]"
    "Color=${toRGB foreground}"
    ""
    "[General]"
    "Anchor=0.5,0.5"
    "Blur=true"
    "ColorRandomization=false"
    "Description=Mokka"
    "FillStyle=Tile"
    "Opacity=0.9"
    "Wallpaper="
    "WallpaperFlipType=NoFlip"
    "WallpaperOpacity=1"
  ]));

  # Konsole profile — matches the stock Garuda.profile (zsh instead of fish).
  konsoleProfile = with m; ''
    [Appearance]
    ColorScheme=Mokka
    Font=JetBrainsMono Nerd Font,12,-1,5,700,0,0,0,0,0,0,0,0,0,0,1,Bold
    UseFontLineChararacters=true

    [Cursor Options]
    CursorShape=2
    CustomCursorColor=255,0,0
    UseCustomCursorColor=true

    [General]
    Command=zsh
    Name=Garuda
    Parent=FALLBACK/
    TerminalColumns=110

    [Interaction Options]
    AutoCopySelectedText=true
    TrimLeadingSpacesInSelectedText=true
    TrimTrailingSpacesInSelectedText=true
    UnderlineFilesEnabled=true

    [Keyboard]
    KeyBindings=default

    [Scrolling]
    HistoryMode=1

    [Terminal Features]
    BlinkingCursorEnabled=true
  '';

  # GNOME Terminal profile UUID (fixed so the dconf paths are stable).
  gnomeProfileId = "b1dcc9dd-5262-4d8d-a863-c897e6d979b9";
in
{
  # Konsole is a KDE Qt app — installed user-level alongside its config.
  home.packages = with pkgs; [ kdePackages.konsole ];

  # ── Konsole: profile + colorscheme + default profile ─────────────
  home.file = {
    ".local/share/konsole/Mokka.colorscheme".text = konsoleColorscheme;
    ".local/share/konsole/Garuda.profile".text = konsoleProfile;
    ".config/konsolerc".text = ''
      [Desktop Entry]
      DefaultProfile=Garuda.profile
    '';
  };

  # ── GNOME Terminal: Mokka profile set as the default ──────────────
  dconf.settings."org/gnome/terminal/legacy/profiles:/:${gnomeProfileId}" = {
    visible-name = "Mokka";
    use-theme-colors = false;
    background-color = m.background;
    foreground-color = m.foreground;
    cursor-color = m.cursor;
    bold-color = m.selectionBackground;
    palette = m.palette;
    use-transparent-background = true;
    background-transparency-percent = 10;
    bold-is-bright = false;
    font = "${m.font} ${toString m.fontSize}";
    scrollback-lines = 5000;
    default-size-columns = 110;
  };

  dconf.settings."org/gnome/terminal/legacy" = {
    default-show-menubar = false;
    theme-variant = "dark";
  };

  dconf.settings."org/gnome/terminal/legacy/profiles:/" = {
    default = "/org/gnome/terminal/legacy/profiles:/:${gnomeProfileId}";
  };
}
