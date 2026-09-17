##############################################################################
#
# Theme — Mokka (KDE Color Scheme)
#
# Purpose
# -------
# Catppuccin Mocha Mauve color scheme for KDE Plasma.
# Derived from the upstream Garuda Mokka repository:
#   https://gitlab.com/garuda-linux/themes-and-settings/settings/garuda-mokka
#   File: usr/share/color-schemes/Mokka.colors
#
# Ownership
# ---------
# theme.mokka.colors
#
##############################################################################

{
  # KDE color scheme name (matches the installed .colors file name)
  name = "Mokka";

  # Catppuccin Mocha base palette (RGB values)
  base = {
    background = "30,30,46";
    foreground = "205,214,244";
    accent = "203,166,247"; # Mauve
  };

  # Window manager colors
  wm = {
    activeBackground = "30, 30, 46";
    activeBlend = "205, 214, 244";
    activeForeground = "205, 214, 244";
    inactiveBackground = "17, 17, 27";
    inactiveBlend = "166, 173, 200";
    inactiveForeground = "166, 173, 200";
  };

  # KDE contrast level (4 = high contrast, Mokka upstream default)
  contrast = 4;

  # Catppuccin Mocha Mauve ANSI terminal palette
  terminal = {
    background = "30,30,46";
    foreground = "205,214,244";
    cursor = "205,214,244";
    selection_bg = "203,166,247";
    selection_fg = "30,30,46";

    # ANSI colors 0-7 (normal)
    black = "30,30,46";
    red = "243,139,168";
    green = "166,227,161";
    yellow = "249,226,175";
    blue = "137,180,250";
    magenta = "203,166,247";
    cyan = "137,220,235";
    white = "205,214,244";

    # ANSI colors 8-15 (bright)
    brBlack = "108,112,134";
    brRed = "243,139,168";
    brGreen = "166,227,161";
    brYellow = "249,226,175";
    brBlue = "137,180,250";
    brMagenta = "203,166,247";
    brCyan = "137,220,235";
    brWhite = "205,214,244";
  };
}
