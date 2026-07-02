#!/usr/bin/env bash
# commands/screenshot.sh — /screenshot — capture desktop
##############################################################################

_cmd_screenshot() {
  local chat="$1" args="$2"
  local file="/tmp/ivali-screenshot-$(date +%s).png"

  send_msg "$chat" "📸 Capturing screenshot…"

  local -a env_args
  session_env_args "$chat" env_args || return

  # Use grim for Wayland screenshots
  if sudo -u "${DEFAULT_USER}" env "${env_args[@]}" grim "$file" 2>/dev/null; then
    send_photo "$chat" "$file" "📸 Screenshot from *${HOST}*"
    rm -f "$file"
  else
    send_msg "$chat" "❌ Screenshot failed. Is grim installed?"
  fi
}

register_command "screenshot" "_cmd_screenshot" "📸 Capture desktop"
