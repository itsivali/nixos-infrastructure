# commands/screenshot.sh — /screenshot — capture desktop via grim + slurp
##############################################################################

_cmd_screenshot() {
  local chat="$1" args="$2"
  local dir="/home/${DEFAULT_USER}/Pictures"
  local file="${dir}/ivali-screenshot-$(date +%Y%m%d-%H%M%S).png"

  send_msg "$chat" "Capturing screenshot..."

  desktop::require_graphical "$chat" || return

  sudo -u "${DEFAULT_USER}" mkdir -p "$dir" 2>/dev/null || true

  if sudo -u "${DEFAULT_USER}" \
    XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
    grim "$file" 2>/dev/null && [[ -f "$file" ]]; then
    send_photo "$chat" "$file" "Screenshot saved to \`~/Pictures/\` on *${HOST}*"
  else
    send_msg "$chat" "Screenshot failed."
  fi
}

register_command "screenshot" "_cmd_screenshot" "Capture desktop"
