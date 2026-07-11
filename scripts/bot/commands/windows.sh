# commands/windows.sh — /windows, /focus <title>, /close <title> — window management
# Uses GNOME Shell D-Bus Eval for window control.
##############################################################################

_cmd_windows() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  desktop::require_graphical "$chat" || return

  local wins
  wins="$(desktop::gnome_shell_json 'JSON.stringify(Array.from(global.get_window_actors()).map(function(a){var w=a.meta_window;return{title:w.title,wm_class:w.get_wm_class(),workspace:w.get_workspace().index()+1}}))' 2>/dev/null)" || true

  if [[ -z "$wins" || "$wins" == "[]" ]]; then
    send_msg "$chat" "No open windows detected."
    return
  fi

  # Count total windows
  local win_count=$(echo "$wins" | jq 'length' 2>/dev/null || echo "?")

  local out="🖥 *${HOST}* — Open Windows (${win_count})
${sep}"

  # Group by workspace
  local ws
  for ws in $(echo "$wins" | jq -r '.[].workspace' 2>/dev/null | sort -un); do
    local ws_wins
    ws_wins=$(echo "$wins" | jq -c --argjson ws "$ws" '.[] | select(.workspace == $ws)' 2>/dev/null)
    local ws_count=$(echo "$ws_wins" | jq 'length' 2>/dev/null || echo "0")

    out+="
*Workspace ${ws}* (${ws_count} windows)"

    while IFS= read -r line; do
      local title wm_class
      title="$(echo "$line" | jq -r '.title // "?"')"
      wm_class="$(echo "$line" | jq -r '.wm_class // "?"')"

      # Truncate long titles
      if [[ ${#title} -gt 40 ]]; then
        title="${title:0:37}..."
      fi

      out+="
  • \`${title}\` [${wm_class}]"
    done < <(echo "$ws_wins" | jq -c '.' 2>/dev/null)
  done

  out+="
${sep}
_use \`/focus <title>\` or \`/close <title>\`_"

  send_long "$chat" "$out"
}

_cmd_focus() {
  local chat="$1" args="$2"

  if [[ -z "$args" ]]; then
    send_msg "$chat" "🔧 *Usage:* \`/focus <window title>\`
_Focus a window by title or class._
_Example:_ \`/focus Firefox\`"
    return
  fi

  desktop::require_graphical "$chat" || return

  local escaped
  escaped="$(echo "$args" | sed "s/'/\\\\\\\\'/g")"
  local result
  result="$(desktop::gnome_shell_eval "global.get_window_actors().find(function(a){var w=a.meta_window;return w.title.includes('${escaped}')||w.get_wm_class().includes('${escaped}')})?.meta_window.activate(global.get_current_time())")"

  if echo "$result" | grep -q "^true"; then
    send_msg "$chat" "✅ Focused: \`${args}\`"
  else
    send_msg "$chat" "❌ Window \`${args}\` not found."
  fi
}

_cmd_close() {
  local chat="$1" args="$2"

  if [[ -z "$args" ]]; then
    send_msg "$chat" "🔧 *Usage:* \`/close <window title>\`
_Close a window by title or class._
_Example:_ \`/close Firefox\`"
    return
  fi

  desktop::require_graphical "$chat" || return

  local escaped
  escaped="$(echo "$args" | sed "s/'/\\\\\\\\'/g")"
  local result
  result="$(desktop::gnome_shell_eval "global.get_window_actors().find(function(a){var w=a.meta_window;return w.title.includes('${escaped}')||w.get_wm_class().includes('${escaped}')})?.meta_window.delete(global.get_current_time())")"

  if echo "$result" | grep -q "^true"; then
    send_msg "$chat" "✅ Closed: \`${args}\`"
  else
    send_msg "$chat" "❌ Window \`${args}\` not found."
  fi
}

register_command "windows" "_cmd_windows" "List open windows"
register_command "focus" "_cmd_focus" "Focus a window"
register_command "close" "_cmd_close" "Close a window"
