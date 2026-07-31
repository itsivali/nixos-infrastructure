#!/usr/bin/env bash
#
# Rofi preset brightness menu used by the Waybar backlight right-click.
# rofi auto-loads the Gruvbox theme from ~/.config/rofi/config.rasi.
#
set -Eeuo pipefail

CHOICE="$(printf '%s\n' 10% 25% 50% 75% 100% | rofi -dmenu -p "Brightness" -i 2>/dev/null || true)"
[[ -z "$CHOICE" ]] && exit 0

brightnessctl set "$CHOICE"
