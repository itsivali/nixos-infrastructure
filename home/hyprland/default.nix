##############################################################################
#
# Home Manager — Hyprland Desktop Environment Module
#
# Purpose
# -------
# Aggregates all user-level Hyprland desktop environment modules: Window Manager,
# Waybar status bar, SwayNC notification center, Hyprlock screen locker, Hypridle,
# Rofi launcher, Wlogout power menu, GNOME application settings, and the theme
# engine.
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
    ./swayosd
    ./networkmanager
    ./hyprlock
    ./hypridle
    ./rofi
    ./gnome
    ./wlogout
    ./hyprpaper
    ./clipboard
    ./emoji
    ./screenshot
    ./hyprsunset
    ./wallpaper
    ./keybindhint
    ./dropdown
    ./gamemode
  ];
}
