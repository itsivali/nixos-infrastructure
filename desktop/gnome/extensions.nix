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
#   dash-to-panel            Full-width top panel with a taskbar: replaces the
#                            stock top bar and dash, macOS-style window switcher
#                            with a centered taskbar.
#   blur-my-shell            Frosted-glass panel / overview polish (matches the
#                            Gruvbox translucent surfaces).
#   appindicator             System tray (AppIndicator/KStatusNotifier): the
#                            only way Discord, Slack and Teams render icons.
#   user-themes              Load the Gruvbox GNOME Shell theme from the user
#                            directory (packages/gnome-shell-gruvbox-theme).
#   just-perfection          Declutter the overview (hide window picker
#                            clutter, tune UI element visibility).
#   tiling-assistant         Keyboard-driven window tiling for developer
#                            multitasking (built-in tiling is 2-column only).
#   clipboard-indicator      Clipboard history (replaces Hyprland cliphist).
#   impatience               Faster, snappier GNOME Shell animations (perf).
#   vitals                   CPU / RAM / battery gauges in the top panel.
#   caffeine                 Per-window display-sleep override (fullscreen
#                            video never sleeps).
#
##############################################################################

{ config, lib, pkgs, self, ... }:

{
  config = lib.mkIf (config.ivali.desktop.gnome.enable or false) {
    environment.systemPackages = with pkgs.gnomeExtensions; [
      dash-to-panel
      blur-my-shell
      appindicator
      user-themes
      just-perfection
      tiling-assistant
      clipboard-indicator
      impatience
      vitals
      caffeine
      # Custom: collapses the right-side indicators (quick settings, vitals,
      # clipboard, tray) behind a chevron; clock stays visible. Source in
      # packages/panel-collapse.
      self.packages.${pkgs.stdenv.hostPlatform.system}.panel-collapse
    ];
  };
}
