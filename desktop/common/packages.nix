##############################################################################
#
# Desktop — Common Packages
#
# Purpose
# -------
# System packages shared by every desktop host, regardless of environment.
# Environment-specific packages (GNOME Shell extensions, app stack, ...)
# live with their environment in desktop/gnome/*.
#
# Ownership
# ---------
# ivali.desktop
#
# Removed during the GNOME migration (replaced by GNOME-native equivalents):
#   grim / slurp / swappy       -> GNOME Shell screenshots (built-in)
#   cliphist                    -> clipboard-indicator extension
#   pamixer                     -> PipeWire / WirePlumber volume API
#   swaynotificationcenter      -> GNOME notification daemon
#   polkit_gnome                -> GNOME Shell polkit authentication agent
#   networkmanagerapplet        -> GNOME Shell network tray icon
#   blueman                     -> GNOME Shell Bluetooth tray icon
#
##############################################################################

{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Wayland clipboard CLI (scripts, bot integration) + X11 equivalent
    # (xclip) so clipboard tooling works on both Wayland (GNOME) and X11
    # (XFCE) desktops. The `clip`/`cclip`/`cclear` shell functions dispatch
    # on the active session type (home/shell/core/clipboard.nix).
    wl-clipboard
    xclip

    # Audio / media key control
    playerctl
    brightnessctl

    # Notifications
    libnotify

    # Interactive tooling for scripts & debugging
    imagemagick
    libva-utils
  ];
}
