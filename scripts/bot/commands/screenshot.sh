# commands/screenshot.sh — /screenshot — capture desktop via gnome-screenshot
# Uses xdg-desktop-portal (shows allow dialog on first use per app).
##############################################################################

_cmd_screenshot() {
  local chat="$1" args="$2"
  local dir="/home/${DEFAULT_USER}/Pictures"
  local file="${dir}/ivali-screenshot-$(date +%Y%m%d-%H%M%S).png"

  send_msg "$chat" "📸 Capturing screenshot…"

  desktop::require_graphical "$chat" || return

  sudo -u "${DEFAULT_USER}" mkdir -p "$dir" 2>/dev/null || true

  if sudo -u "${DEFAULT_USER}" \
    XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
    WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
    DISPLAY="$DISPLAY" \
    gnome-screenshot -f "$file" 2>/dev/null && [[ -f "$file" ]]; then
    send_photo "$chat" "$file" "📸 Screenshot saved to \`~/Pictures/\` on *${HOST}*"
  else
    send_msg "$chat" "❌ Screenshot failed. A permission dialog may have appeared on your screen — click *Allow* and try again."
  fi
}

register_command "screenshot" "_cmd_screenshot" "📸 Capture desktop"
