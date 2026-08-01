##############################################################################
#
# Desktop — Common Packages
#
# Purpose
# -------
# System packages shared by every desktop host, regardless of environment.
# Environment-specific packages (hyprland, waybar, rofi, ...) live with
# their environment in desktop/hyprland/packages.nix.
#
# Ownership
# ---------
# ivali.desktop
#
##############################################################################

{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Wayland-native screenshot + clipboard stack
    grim
    slurp
    swappy
    wl-clipboard
    cliphist

    # Audio / media key control
    pavucontrol
    pamixer
    playerctl
    brightnessctl

    # Notifications + polkit agent
    swaynotificationcenter
    libnotify
    polkit_gnome

    # Tray / system integration
    networkmanagerapplet
    blueman

    # Interactive tooling for status bars & scripts
    imagemagick
    jq
    libva-utils
  ];
}
