##############################################################################
#
# Home Manager — Hyprland Desktop Environment Module
#
# Purpose
# -------
# Aggregates all user-level Hyprland desktop environment modules: Window Manager,
# Waybar status bar, SwayNC notification center, Hyprlock screen locker, Hypridle,
# Rofi (dmenu plumbing), KRunner launcher, Wlogout power menu, Konsole terminal,
# and theme engine.
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
    ./krunner
    ./kde
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
