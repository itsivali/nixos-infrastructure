# commands/workspace.sh — /workspace next|prev|N — workspace switching
# Uses DesktopControl GNOME Shell extension (Wayland-native via D-Bus).
#
# D-Bus methods (v2):
#   CurrentWorkspace  → integer (active workspace index)
#   WorkspaceCount    → integer (total workspace count)
#   SwitchWorkspace(i) → JSON {ok, data} response
##############################################################################

_cmd_workspace() {
  local chat="$1" args="$2"

  if [[ -z "$args" ]]; then
    send_msg "$chat" "🔧 *Usage:* \`/workspace <next|prev|N>\`
_Switch desktop workspaces._
_Examples:_ \`/workspace next\`, \`/workspace 3\`"
    return
  fi

  desktop::require_graphical "$chat" || return

  # Get current workspace index (v2: CurrentWorkspace)
  local current_result
  current_result="$(desktop::ext_dbus_call CurrentWorkspace)" || true
  local current
  current="$(echo "$current_result" | grep -oP '\d+')"

  # Get total workspace count (v2: WorkspaceCount)
  local total_result
  total_result="$(desktop::ext_dbus_call WorkspaceCount)" || true
  local total
  total="$(echo "$total_result" | grep -oP '\d+')"

  case "$args" in
    next)
      if [[ -n "$current" && -n "$total" ]]; then
        local next_ws=$(( current + 1 ))
        (( next_ws >= total )) && next_ws=0
        local result
        result="$(desktop::ext_dbus_call SwitchWorkspace "$next_ws")" || true
        send_msg "$chat" "🖥 Workspace → ${next_ws}"
      else
        send_msg "$chat" "❌ Could not detect current workspace."
      fi
      ;;
    prev)
      if [[ -n "$current" && -n "$total" ]]; then
        local prev_ws=$(( current - 1 ))
        (( prev_ws < 0 )) && prev_ws=$(( total - 1 ))
        local result
        result="$(desktop::ext_dbus_call SwitchWorkspace "$prev_ws")" || true
        send_msg "$chat" "🖥 Workspace → ${prev_ws}"
      else
        send_msg "$chat" "❌ Could not detect current workspace."
      fi
      ;;
    [0-9]*)
      local target="$args"
      local result
      result="$(desktop::ext_dbus_call SwitchWorkspace "$target")" || true

      # Parse structured JSON response
      local json
      json="$(echo "$result" | sed "s/^('//; s/'.*$//; s/\\\\//g")"

      if echo "$json" | jq -e '.ok and .data' >/dev/null 2>&1; then
        send_msg "$chat" "🖥 Workspace → ${target}"
      elif echo "$json" | jq -e '.ok and (.data | not)' >/dev/null 2>&1; then
        send_msg "$chat" "❌ Workspace ${target} does not exist."
      else
        send_msg "$chat" "❌ Could not switch to workspace ${target}."
      fi
      ;;
    *)
      send_msg "$chat" "🔧 *Usage:* \`/workspace <next|prev|N>\`"
      ;;
  esac
}

register_command "workspace" "_cmd_workspace" "🖥 Switch workspaces"
