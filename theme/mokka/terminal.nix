##############################################################################
#
# Theme — Mokka (Konsole Terminal Profile)
#
# Purpose
# -------
# Konsole color scheme for Catppuccin Mocha Mauve.
# Derived from upstream Garuda Mokka:
#   https://gitlab.com/garuda-linux/themes-and-settings/settings/garuda-mokka
#   File: usr/share/konsole/Mokka.colorscheme
#
# Ownership
# ---------
# theme.mokka.terminal
#
##############################################################################

{ colors }:

{
  # Konsole profile metadata
  name = "Mokka";
  description = "Catppuccin Mocha Mauve — Garuda Mokka";

  # Background and transparency
  background = {
    color = colors.background;
    opacity = 0.9;
    blur = true;
  };

  # Foreground
  foreground = colors.foreground;

  # Cursor
  cursor = {
    color = colors.foreground;
    shape = "Block";
  };

  # Selection
  selection = {
    background = colors.selection_bg;
    foreground = colors.selection_fg;
  };

  # ANSI colors — Catppuccin Mocha palette
  colors = {
    # Normal (0-7)
    black = colors.black;
    red = colors.red;
    green = colors.green;
    yellow = colors.yellow;
    blue = colors.blue;
    magenta = colors.magenta;
    cyan = colors.cyan;
    white = colors.white;

    # Bright (8-15)
    brightBlack = colors.brBlack;
    brightRed = colors.brRed;
    brightGreen = colors.brGreen;
    brightYellow = colors.brYellow;
    brightBlue = colors.brBlue;
    brightMagenta = colors.brMagenta;
    brightCyan = colors.brCyan;
    brightWhite = colors.brWhite;
  };
}
