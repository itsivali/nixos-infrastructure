##############################################################################
#
# Desktop — GNOME Shell Extensions
#
# Purpose
# -------
# Curated GNOME Shell extension set for GNOME 50 (Tokyo). Every extension has
# a distinct purpose; none overlaps with another. Enabled + configured per-user
# via dconf in home/gnome/extensions.nix.
#
# Ownership
# ---------
# ivali.desktop.gnome
#
# Extension rationale
# -------------------
#   dash-to-dock              macOS-style fixed dock: primary launcher,
#                             task switcher, badge notifications.
#   blur-my-shell             Frosted-glass panel / dock / overview polish
#                             (matches the Gruvbox translucent surfaces).
#   appindicator              System tray (AppIndicator/KStatusNotifier): the
#                             only way Discord, Slack and Teams render icons.
#   user-themes               Load the Gruvbox GNOME Shell theme from the user
#                             directory (packages/gnome-shell-gruvbox-theme).
#   just-perfection           Declutter the overview (hide window picker
#                             clutter, tune UI element visibility).
#   tiling-assistant          Keyboard-driven window tiling for developer
#                             multitasking (built-in tiling is 2-column only).
#   clipboard-indicator       Clipboard history (replaces Hyprland cliphist).
#   sound-output-device-chooser  One-click audio sink/source switching for
#                             Meet / Zoom device changes.
#   impatience                Faster, snappier GNOME Shell animations (perf).
#   battery-time              Battery % + time remaining in the top bar.
#   vitals                    CPU / RAM / battery gauges in the top bar.
#   caffeine                  Per-window display-sleep override (fullscreen
#                             video never sleeps).
#
##############################################################################

{ config, lib, pkgs, ... }:

{
  config = lib.mkIf (config.ivali.desktop.gnome.enable or false) {
    environment.systemPackages = with pkgs.gnomeExtensions; [
      dash-to-dock
      blur-my-shell
      appindicator
      user-themes
      just-perfection
      tiling-assistant
      clipboard-indicator
      sound-output-device-chooser
      impatience
      battery-time
      vitals
      caffeine
    ];
  };
}
