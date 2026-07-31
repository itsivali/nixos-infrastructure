##############################################################################
#
# Packages Waybar Helpers
#
# Purpose
# -------
# Packaged shell helper scripts used by Waybar module click handlers
# (power-profile-cycle, brightness-menu, switch-user).
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Package interactive helper scripts for the Waybar status bar
# - Be importable by the system package aggregator
#
##############################################################################

# Interactive Waybar helper scripts — combined into system package set.
{ pkgs }:

let
  mkScript = name: runtimeInputs: src: pkgs.writeShellApplication {
    inherit name runtimeInputs;
    text = builtins.readFile src;
  };
  shared = with pkgs; [
    bash
    libnotify
  ];
in
[
  (mkScript "power-profile-cycle" (shared ++ [ pkgs.power-profiles-daemon ])
    ../../scripts/waybar/power-profile-cycle.sh)
  (mkScript "brightness-menu"
    (shared ++ [ pkgs.brightnessctl pkgs.rofi ])
    ../../scripts/waybar/brightness-menu.sh)
  (mkScript "switch-user"
    (shared ++ [ pkgs.glib pkgs.hyprlock ])
    ../../scripts/waybar/switch-user.sh)
  (mkScript "waybar-toggle"
    (shared ++ [ pkgs.procps pkgs.util-linux pkgs.waybar ])
    ../../scripts/waybar/toggle.sh)
]
