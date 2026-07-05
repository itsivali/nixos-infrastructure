# commands/windows.sh — /windows, /focus <title>, /close <title> — window management
# Uses DesktopControl GNOME Shell extension (Wayland-native via D-Bus).
#
# D-Bus methods (v2):
#   ListWindows      → JSON array of window objects
#   FocusWindow(s)   → JSON {ok, data} response
#   CloseWindow(s)   → JSON {ok, data} response
##############################################################################

_cmd_windows() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  desktop::require_graphical "$chat" || return

  local result
  result="$(desktop::ext_dbus_call ListWindows)" || true

  if [[ -z "$result" ]]; then
    send_msg "$chat" "❌ Could not list windows. Is the DesktopControl extension installed and enabled?
Restart GNOME Shell (Alt+F2 → \`r\`) or log out and back in."
    return
  fi

  # D-Bus returns: ('[...]',) — extract the JSON array
  local json
  json="$(echo "$result" | sed "s/^('//; s/'.*$//; s/\\\\//g")"

  if [[ "$json" == "[]" ]]; then
    send_msg "$chat" "🪟 No open windows detected."
    return
  fi

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

  if [[ -z "$result" ]]; then
    send_msg "$chat" "❌ Could not focus window. Is the DesktopControl extension installed and enabled?"
    return
  fi

  # Response: ('{"ok":true,"data":true}',) — extract JSON
  local json
  json="$(echo "$result" | sed "s/^('//; s/'.*$//; s/\\\\//g")"

  if echo "$json" | jq -e '.ok and .data' >/dev/null 2>&1; then
    send_msg "$chat" "🪟 Focused: \`${args}\`"
  elif echo "$json" | jq -e '.ok and (.data | not)' >/dev/null 2>&1; then
    send_msg "$chat" "❌ Window \`${args}\` not found."
  else
    send_msg "$chat" "❌ Could not focus window."
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

  if [[ -z "$result" ]]; then
    send_msg "$chat" "❌ Could not close window. Is the DesktopControl extension installed and enabled?"
    return
  fi

  # Response: ('{"ok":true,"data":true}',) — extract JSON
  local json
  json="$(echo "$result" | sed "s/^('//; s/'.*$//; s/\\\\//g")"

  if echo "$json" | jq -e '.ok and .data' >/dev/null 2>&1; then
    send_msg "$chat" "🪟 Closed: \`${args}\`"
  elif echo "$json" | jq -e '.ok and (.data | not)' >/dev/null 2>&1; then
    send_msg "$chat" "❌ Window \`${args}\` not found."
  else
    send_msg "$chat" "❌ Could not close window."
  fi
}

register_command "windows" "_cmd_windows" "🪟 List open windows"
register_command "focus" "_cmd_focus" "🪟 Focus a window"
register_command "close" "_cmd_close" "🪟 Close a window"
