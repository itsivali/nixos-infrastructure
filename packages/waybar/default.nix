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
  mkScript = name: src: pkgs.writeShellApplication {
    inherit name;
    text = builtins.readFile src;
    runtimeInputs = with pkgs; [
      brightnessctl
      glib
      hyprlock
      libnotify
      power-profiles-daemon
      rofi
    ];
  };
in
[
  (mkScript "power-profile-cycle" ../../scripts/waybar/power-profile-cycle.sh)
  (mkScript "brightness-menu" ../../scripts/waybar/brightness-menu.sh)
  (mkScript "switch-user" ../../scripts/waybar/switch-user.sh)
]
