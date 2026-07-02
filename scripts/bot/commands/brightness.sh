#!/usr/bin/env bash
# commands/brightness.sh — /brightness [N] — backlight control
##############################################################################

_cmd_brightness() {
  local chat="$1" args="$2"

  if [[ -z "$args" ]]; then
    # Show current brightness
    local info
    info="$(brightnessctl info 2>/dev/null | grep -oP '\d+%' | head -1)" || true
    send_msg "$chat" "🔆 Brightness: ${info:-unknown}"
    return
  fi

  local value="$args"
  value="${value%%%}"

  if [[ "$value" =~ ^[0-9]+$ ]] && (( value >= 0 && value <= 100 )); then
    brightnessctl set "${value}%" 2>/dev/null
    send_msg "$chat" "🔆 Brightness set to ${value}%"
  else
    send_msg "$chat" "🔧 *Usage:* \`/brightness <0-100>\`"
  fi
}

register_command "brightness" "_cmd_brightness" "🔆 Brightness control"
