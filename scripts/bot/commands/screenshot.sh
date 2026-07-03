#!/usr/bin/env bash
# commands/screenshot.sh — /screenshot — capture desktop via gnome-screenshot
##############################################################################

_cmd_screenshot() {
  local chat="$1" args="$2"
  local file="/tmp/ivali-screenshot-$(date +%s).png"

  send_msg "$chat" "📸 Capturing screenshot…"

  local -a env_args
  session_env_args "$chat" env_args || return

  local ss_bin
  ss_bin="$(resolve_binary gnome-screenshot)" || true
  if [[ -z "$ss_bin" ]]; then
    send_msg "$chat" "❌ gnome-screenshot not found on ${HOST}."
    return
  fi

  if sudo -u "${DEFAULT_USER}" env "${env_args[@]}" "$ss_bin" -f "$file" 2>/dev/null; then
    send_photo "$chat" "$file" "📸 Screenshot from *${HOST}*"
    rm -f "$file"
  else
    send_msg "$chat" "❌ Screenshot failed. Is gnome-screenshot installed?"
  fi
}

register_command "screenshot" "_cmd_screenshot" "📸 Capture desktop"
