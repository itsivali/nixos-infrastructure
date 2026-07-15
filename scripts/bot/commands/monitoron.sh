# commands/monitoron.sh — /monitoron — turn on the monitor/display
##############################################################################

_cmd_monitoron() {
  local chat="$1" args="$2"

  desktop::require_graphical "$chat" || return

  local mon_bin=""
  if command -v brightnessctl >/dev/null 2>&1; then
    mon_bin="brightnessctl"
  fi

  if [[ -z "$mon_bin" ]]; then
    send_msg "$chat" "❌ brightnessctl not found on ${HOST}."
    return
  fi

  # Set brightness to 50% (unblank the display)
  $mon_bin set 50% 2>/dev/null

  # Also try xdotool to deactivate screen blank if X11 session
  if [[ "$(desktop::session_type)" == "x11" ]]; then
    xdotool key Shift+Escape 2>/dev/null || true
  fi

  send_msg "$chat" "🖥 Monitor turned on."
}

register_command "monitoron" "_cmd_monitoron" "🖥 Turn on the monitor"
