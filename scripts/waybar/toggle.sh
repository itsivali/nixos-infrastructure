#!/usr/bin/env bash
#
# Toggle the Waybar status bar on/off.
#
# Waybar is started from Hyprland's exec-once; this toggles it on demand.
# nixpkgs wraps the waybar binary as .waybar-wrapped, so the process name
# (comm) is ".waybar-wrapped" rather than "waybar" - match on that exact
# name for both detection and kill. When (re)starting, detach with setsid
# so the bar survives the launching shell exiting.
#
set -Eeuo pipefail

if pgrep -x .waybar-wrapped >/dev/null 2>&1; then
  pkill -x .waybar-wrapped
else
  setsid waybar >/dev/null 2>&1 &
fi
