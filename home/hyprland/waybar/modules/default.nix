##############################################################################
#
# Home — Waybar Module Aggregator
#
# Purpose
# -------
# Imports every per-module Waybar config file and merges them into a single
# module attrset consumed by home/hyprland/waybar/default.nix.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
##############################################################################

let
  modules = [
    ./appmenu.nix
    ./workspaces.nix
    ./window.nix
    ./clock.nix
    ./cpu.nix
    ./memory.nix
    ./updates.nix
    ./pulseaudio.nix
    ./backlight.nix
    ./network.nix
    ./bluetooth.nix
    ./battery.nix
    ./idle-inhibitor.nix
    ./notification.nix
    ./power.nix
  ];
in
builtins.foldl' (acc: m: acc // (import m)) { } modules
