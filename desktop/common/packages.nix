##############################################################################
#
# Desktop — Common Packages
#
# Purpose
# -------
# System packages shared by every desktop host, regardless of environment.
# Environment-specific packages (app stack, power, ...) live with their
# environment in desktop/kde/* or desktop/gnome/*.
#
# Ownership
# ---------
# ivali.desktop
#
##############################################################################

{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Wayland clipboard CLI (scripts, bot integration) + X11 equivalent
    # (xclip) so clipboard tooling works on both Wayland and X11 desktops.
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
