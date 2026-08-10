##############################################################################
#
# Home — Kitty Terminal
#
# Purpose
# -------
# Kitty terminal styled like the Garuda Linux default terminal: the Mokka
# (Catppuccin Mocha) color scheme, JetBrainsMono Nerd Font, red block
# cursor, and 90% background opacity. The rest of the desktop stays on the
# Gruvbox design system — only the terminal emulator carries the Garuda
# look. Kitty is the default terminal for the whole desktop (GNOME
# keybindings, Rofi, and Nautilus "Open in Terminal" all launch it).
#
# Ownership
# ---------
# programs.kitty, ivali.theme.mokka
#
# Responsibilities
# ----------------
# - Install Kitty
# - Write the Mokka color scheme into ~/.config/kitty/kitty.conf
# - Provide the base profile reused by the dropdown terminal (launched with
#   --class kitty-dropdown and floated by Hyprland window rules)
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  theme = import ../../theme/gruvbox/default.nix;
  m = theme.mokka;

  palette = m.palette;
  colorOf = i:
    let
      c = builtins.elemAt palette i;
    in
    c;
in
{
  programs.kitty = {
    enable = true;

    settings = {
      font_family = m.font;
      font_size = m.fontSize;

      # Garuda Konsole defaults to a 110-column window
      window_size = "110x35";

      # Konsole Opacity=0.9
      background_opacity = m.opacity;
      dynamic_background_opacity = "yes";

      background = m.background;
      foreground = m.foreground;
      cursor = m.cursor;
      cursor_text_color = m.cursorText;
      # Konsole CursorShape=2 (block)
      cursor_shape = "block";
      selection_background = m.selectionBackground;
      selection_foreground = m.selectionForeground;
      url_color = m.url;

      color0 = colorOf 0;
      color1 = colorOf 1;
      color2 = colorOf 2;
      color3 = colorOf 3;
      color4 = colorOf 4;
      color5 = colorOf 5;
      color6 = colorOf 6;
      color7 = colorOf 7;
      color8 = colorOf 8;
      color9 = colorOf 9;
      color10 = colorOf 10;
      color11 = colorOf 11;
      color12 = colorOf 12;
      color13 = colorOf 13;
      color14 = colorOf 14;
      color15 = colorOf 15;
    };
  };
}
