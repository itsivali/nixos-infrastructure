# commands/windows.sh — /windows, /focus <title>, /close <title> — window management
# Uses DesktopControl GNOME Shell extension (Wayland-native via D-Bus).
##############################################################################

_cmd_windows() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  desktop::require_graphical "$chat" || return

  local result
  result="$(desktop::ext_dbus_call ListWindows)" || true

  if [[ -z "$result" || "$result" == *'[]'* ]]; then
    send_msg "$chat" "🪟 No open windows detected."
    return
  fi

  # Parse JSON from D-Bus response: ('[...]',) → extract JSON array
  local json
  json="$(echo "$result" | sed "s/^('//; s/'.*$//; s/\\\\//g")"

  local wins
  wins="$(echo "$json" | jq -r '.[] | "• \(.title) [\(.wm_class)] (ws:\(.workspace))"' 2>/dev/null)" || true

  if [[ -z "$wins" ]]; then
    send_msg "$chat" "🪟 No open windows detected."
    return
  fi

  local out="🪟 *Open Windows*
${sep}
\`\`\`
${wins}
\`\`\`"

  send_long "$chat" "$out"
}

_cmd_focus() {
  local chat="$1" args="$2"

  if [[ -z "$args" ]]; then
    send_msg "$chat" "🔧 *Usage:* \`/focus <window title>\`
_Focus a window by title or WM class._
_Example:_ \`/focus Firefox\`"
    return
  fi

  desktop::require_graphical "$chat" || return

  local result
  result="$(desktop::ext_dbus_call FocusWindow "$args")" || true

  if echo "$result" | grep -q "true"; then
    send_msg "$chat" "🪟 Focused: \`${args}\`"
  else
    send_msg "$chat" "❌ Window \`${args}\` not found."
  fi
}

_cmd_close() {
  local chat="$1" args="$2"

  if [[ -z "$args" ]]; then
    send_msg "$chat" "🔧 *Usage:* \`/close <window title>\`
_Close a window by title or WM class._
_Example:_ \`/close Firefox\`"
    return
  fi

  desktop::require_graphical "$chat" || return

  local result
  result="$(desktop::ext_dbus_call CloseWindow "$args")" || true

  if echo "$result" | grep -q "true"; then
    send_msg "$chat" "🪟 Closed: \`${args}\`"
  else
    send_msg "$chat" "❌ Window \`${args}\` not found."
  fi
}

register_command "windows" "_cmd_windows" "🪟 List open windows"
register_command "focus" "_cmd_focus" "🪟 Focus a window"
register_command "close" "_cmd_close" "🪟 Close a window"
