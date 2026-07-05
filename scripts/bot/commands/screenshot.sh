# commands/screenshot.sh — /screenshot — capture desktop via grim (Wayland-native)
##############################################################################

_cmd_screenshot() {
  local chat="$1" args="$2"
  local file
  file="/tmp/ivali-screenshot-$(date +%s).png"

  send_msg "$chat" "📸 Capturing screenshot…"

  desktop::require_graphical "$chat" || return

  if sudo -u "${DEFAULT_USER}" \
    XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
    grim "$file" 2>/dev/null && [[ -f "$file" ]]; then
    send_photo "$chat" "$file" "📸 Screenshot from *${HOST}*"
    rm -f "$file"
  else
    send_msg "$chat" "❌ Screenshot failed. Is grim installed and is Wayland running?"
  fi
}

register_command "screenshot" "_cmd_screenshot" "📸 Capture desktop"
