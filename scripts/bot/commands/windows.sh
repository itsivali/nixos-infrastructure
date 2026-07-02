#!/usr/bin/env bash
# commands/windows.sh — /windows, /focus <app>, /close <app> — window management
##############################################################################

_cmd_windows() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  # List open windows via wmctrl (works through XWayland on GNOME)
  local wins
  wins="$(wmctrl -l 2>/dev/null)" || true

  if [[ -z "$wins" ]]; then
    send_msg "$chat" "🪟 No open windows detected (wmctrl unavailable or no XWayland)."
    return
  fi

  local out="🪟 *Open Windows*
${sep}
\`\`\`"
  out+="$wins"
  out+="
\`\`\`"

  send_long "$chat" "$out"
}

_cmd_focus() {
  local chat="$1" args="$2"

  if [[ -z "$args" ]]; then
    send_msg "$chat" "🔧 *Usage:* \`/focus <window title>\`
_Focus a window by title._
_Example:_ \`/focus Firefox\`"
    return
  fi

  if wmctrl -a "$args" 2>/dev/null; then
    send_msg "$chat" "🪟 Focused: \`${args}\`"
  else
    send_msg "$chat" "❌ Window \`${args}\` not found."
  fi
}

_cmd_close() {
  local chat="$1" args="$2"

  if [[ -z "$args" ]]; then
    send_msg "$chat" "🔧 *Usage:* \`/close <window title>\`
_Close a window by title._
_Example:_ \`/close Firefox\`"
    return
  fi

  if wmctrl -c "$args" 2>/dev/null; then
    send_msg "$chat" "🪟 Closed: \`${args}\`"
  else
    send_msg "$chat" "❌ Window \`${args}\` not found."
  fi
}

register_command "windows" "_cmd_windows" "🪟 List open windows"
register_command "focus" "_cmd_focus" "🪟 Focus a window"
register_command "close" "_cmd_close" "🪟 Close a window"
