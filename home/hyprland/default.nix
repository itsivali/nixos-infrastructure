##############################################################################
#
# Home Manager — Hyprland Desktop Environment Module
#
# Purpose
# -------
# Aggregates all user-level Hyprland desktop environment modules: Window Manager,
# Waybar status bar, SwayNC notification center, Hyprlock screen locker, Hypridle,
# Rofi application launcher, Wlogout power menu, Kitty terminal, and theme engine.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
##############################################################################

{ ... }:

{
  wayland.systemd.target = "hyprland-session.target";

  imports = [
    ./hypr
    ./waybar
    ./swaync
    ./hyprlock
    ./hypridle
    ./rofi
    ./wlogout
    ./terminal/kitty.nix
    ./hyprpaper
    ./clipboard
    ./emoji
    ./screenshot
    ./hyprsunset
    ./wallpaper
    ./keybindhint
    ./themeselect
    ./dropdown
    ./gamemode
  ];
}
