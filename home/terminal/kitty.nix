##############################################################################
#
# Home — Kitty Terminal
#
# Purpose
# -------
# Kitty terminal configured with the Gruvbox color scheme, MesloLGS NF font,
# and 95% background opacity. Kitty is the default terminal for the whole
# desktop (Hyprland keybindings, Rofi, Waybar, networkmanager-dmenu, and
# Nautilus "Open in Terminal" all launch it).
#
# Ownership
# ---------
# programs.kitty, ivali.theme
#
# Responsibilities
# ----------------
# - Install Kitty
# - Write the Gruvbox color scheme into ~/.config/kitty/kitty.conf
# - Provide the base profile reused by the dropdown terminal (launched with
#   --class kitty-dropdown and floated by Hyprland window rules)
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  theme = import ../../theme/gruvbox/default.nix;
  k = theme.kitty;

  palette = k.palette;
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
      font_family = theme.fonts.monospace;
      font_size = theme.fonts.size;

      background_opacity = "0.95";
      dynamic_background_opacity = "yes";

      background = k.background;
      foreground = k.foreground;
      cursor = theme.colors.orange;
      cursor_text_color = theme.colors.bgHard;
      selection_background = theme.colors.orange;
      selection_foreground = theme.colors.bgHard;
      url_color = theme.colors.blue;

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
