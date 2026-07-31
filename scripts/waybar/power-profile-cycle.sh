#!/usr/bin/env bash
#
# Cycle power-profiles-daemon profiles and notify of the new active profile.
# Falls back gracefully when the hardware exposes no power profiles.
#
set -Eeuo pipefail

CURRENT="$(powerprofilesctl get 2>/dev/null || true)"
if [[ -z "$CURRENT" ]]; then
  notify-send -a waybar -u low "Power profile" "No power profiles available on this hardware"
  exit 0
fi

FIRST=""
NEXT=""
found=0
while IFS= read -r line; do
  # Skip indented sub-lines (drivers) and blank lines; keep top-level "name:"
  case "$line" in
    " "* | "") continue ;;
  esac

  name="${line%%:*}"
  name="${name//\*/}"
  name="${name//[[:space:]]/}"
  [[ -z "$name" ]] && continue

  if [[ -z "$FIRST" ]]; then
    FIRST="$name"
  fi
  if [[ "$found" -eq 1 ]]; then
    NEXT="$name"
    break
  fi
  [[ "$name" == "$CURRENT" ]] && found=1
done <<< "$(powerprofilesctl list 2>/dev/null || true)"

NEXT="${NEXT:-$FIRST}"

if [[ "$NEXT" == "$CURRENT" ]]; then
  notify-send -a waybar -u low "Power profile" "Already on ${CURRENT}"
  exit 0
fi

powerprofilesctl set "$NEXT"
notify-send -a waybar -u low "Power profile" "Switched to ${NEXT}"
