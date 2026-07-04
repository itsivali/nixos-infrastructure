# commands/screenshot.sh — /screenshot — capture desktop via GNOME Shell extension D-Bus
##############################################################################

_cmd_screenshot() {
  local chat="$1" args="$2"
  local file
  file="/tmp/ivali-screenshot-$(date +%s).png"

  send_msg "$chat" "📸 Capturing screenshot…"

  desktop::require_graphical "$chat" || return

  local result
  result="$(desktop::ext_dbus_call Screenshot "$file")" || true

  if echo "$result" | grep -q "true"; then
    if [[ -f "$file" ]]; then
      send_photo "$chat" "$file" "📸 Screenshot from *${HOST}*"
      rm -f "$file"
    else
      send_msg "$chat" "❌ Screenshot captured but file not found at expected path."
    fi
  else
    send_msg "$chat" "❌ Screenshot failed. Is the DesktopControl extension installed and enabled?"
  fi
}

register_command "screenshot" "_cmd_screenshot" "📸 Capture desktop"
