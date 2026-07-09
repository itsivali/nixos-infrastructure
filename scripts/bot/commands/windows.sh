# commands/windows.sh — /windows, /focus <title>, /close <title> — window management
# Uses hyprctl for Hyprland window control.
##############################################################################

_cmd_windows() {
  local chat="$1" args="$2"
  local sep="\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501"

  desktop::require_graphical "$chat" || return

  local wins
  wins="$(desktop::hyprctl_json clients | jq -r '.[] | "\(.title) [\(.class)] (ws: \(.workspace.id))"' 2>/dev/null)" || true

  if [[ -z "$wins" ]]; then
    send_msg "$chat" "No open windows detected."
    return
  fi

  local out="*Open Windows*
${sep}
\`\`\`
${wins}
\`\`\`"

  send_long "$chat" "$out"
}

_cmd_focus() {
  local chat="$1" args="$2"

  if [[ -z "$args" ]]; then
    send_msg "$chat" "*Usage:* \`/focus <window title>\`
_Focus a window by title or class._
_Example:_ \`/focus Firefox\`"
    return
  fi

  desktop::require_graphical "$chat" || return

  desktop::hyprctl_call dispatch focuswindow "title:${args}" >/dev/null 2>&1 && \
    send_msg "$chat" "Focused: \`${args}\`" || \
    send_msg "$chat" "Window \`${args}\` not found."
}

_cmd_close() {
  local chat="$1" args="$2"

  if [[ -z "$args" ]]; then
    send_msg "$chat" "*Usage:* \`/close <window title>\`
_Close a window by title or class._
_Example:_ \`/close Firefox\`"
    return
  fi

  desktop::require_graphical "$chat" || return

  desktop::hyprctl_call dispatch closewindow "title:${args}" >/dev/null 2>&1 && \
    send_msg "$chat" "Closed: \`${args}\`" || \
    send_msg "$chat" "Window \`${args}\` not found."
}

register_command "windows" "_cmd_windows" "List open windows"
register_command "focus" "_cmd_focus" "Focus a window"
register_command "close" "_cmd_close" "Close a window"
