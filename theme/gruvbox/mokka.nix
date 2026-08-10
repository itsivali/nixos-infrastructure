##############################################################################
#
# Theme — Mokka (Garuda Terminal)
#
# Purpose
# -------
# The "Mokka" color scheme used by the Garuda Linux default Konsole profile.
# It is a Catppuccin-Mocha palette (background #1e1e2e, foreground
# #cdd6f4). Also carries the Garuda terminal appearance: JetBrainsMono
# Nerd Font, red block cursor, and 90% opacity. Consumed by
# home/terminal/kitty.nix so the Kitty terminal matches the Garuda look
# while the rest of the desktop stays Gruvbox.
#
# Ownership
# ---------
# theme.gruvbox.mokka
#
##############################################################################

{
  name = "mokka";
  displayName = "Mokka (Garuda)";

  font = "JetBrainsMono Nerd Font";
  fontSize = 12;

  # Konsole's Opacity=0.9 → Kitty background_opacity
  opacity = "0.9";

  background = "#1e1e2e";
  foreground = "#cdd6f4";

  # Garuda Konsole: CustomCursorColor=255,0,0 (red block cursor)
  cursor = "#ff0000";
  cursorText = "#1e1e2e";

  selectionBackground = "#89b4fa";
  selectionForeground = "#1e1e2e";
  url = "#89b4fa";

  palette = [
    "#6c7086" # color0  black     (overlay0)
    "#f38ba8" # color1  red
    "#a6e3a1" # color2  green
    "#f9e1af" # color3  yellow
    "#89b4fa" # color4  blue
    "#cba6f7" # color5  magenta   (mauve)
    "#89dceb" # color6  cyan      (sky)
    "#cdd6f4" # color7  white     (text)
    "#6c7086" # color8  bright black
    "#f38ba8" # color9  bright red
    "#a6e3a1" # color10 bright green
    "#f9e1af" # color11 bright yellow
    "#89b4fa" # color12 bright blue
    "#cba6f7" # color13 bright magenta
    "#89dceb" # color14 bright cyan
    "#cdd6f4" # color15 bright white
  ];
}
