# commands/workspace.sh — /workspace next|prev|N — workspace switching
# Uses DesktopControl GNOME Shell extension (Wayland-native via D-Bus).
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

  # Get current workspace index
  local current_result
  current_result="$(desktop::ext_dbus_call GetActiveWorkspace)" || true
  local current
  current="$(echo "$current_result" | grep -oP '\d+')"

  # Get total workspace count
  local total_result
  total_result="$(desktop::ext_dbus_call GetWorkspaceCount)" || true
  local total
  total="$(echo "$total_result" | grep -oP '\d+')"

  case "$args" in
    next)
      if [[ -n "$current" && -n "$total" ]]; then
        local next_ws=$(( current + 1 ))
        (( next_ws >= total )) && next_ws=0
        desktop::ext_dbus_call SwitchWorkspace "$next_ws"
        send_msg "$chat" "🖥 Workspace → ${next_ws}"
      else
        send_msg "$chat" "❌ Could not detect current workspace."
      fi
      ;;
    prev)
      if [[ -n "$current" && -n "$total" ]]; then
        local prev_ws=$(( current - 1 ))
        (( prev_ws < 0 )) && prev_ws=$(( total - 1 ))
        desktop::ext_dbus_call SwitchWorkspace "$prev_ws"
        send_msg "$chat" "🖥 Workspace → ${prev_ws}"
      else
        send_msg "$chat" "❌ Could not detect current workspace."
      fi
      ;;
    [0-9]*)
      local target="$args"
      if desktop::ext_dbus_call SwitchWorkspace "$target" | grep -q "true"; then
        send_msg "$chat" "🖥 Workspace → ${target}"
      else
        send_msg "$chat" "❌ Workspace ${target} does not exist."
      fi
      ;;
    *)
      send_msg "$chat" "🔧 *Usage:* \`/workspace <next|prev|N>\`"
      ;;
  esac
}

register_command "workspace" "_cmd_workspace" "🖥 Switch workspaces"
