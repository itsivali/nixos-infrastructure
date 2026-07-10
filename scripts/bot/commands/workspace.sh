# commands/workspace.sh — /workspace next|prev|N — workspace switching
# Uses GNOME Shell D-Bus Eval for workspace control.
##############################################################################

_cmd_workspace() {
  local chat="$1" args="$2"

  if [[ -z "$args" ]]; then
    send_msg "$chat" "*Usage:* \`/workspace <next|prev|N>\`
_Switch GNOME workspaces._
_Examples:_ \`/workspace next\`, \`/workspace 3\`"
    return
  fi

  desktop::require_graphical "$chat" || return

  case "$args" in
    next)
      desktop::gnome_shell_eval "global.workspace_manager.get_workspace_by_index(Math.min(global.workspace_manager.n_workspaces-1,global.workspace_manager.get_active_workspace_index()+1)).activate(global.get_current_time())"
      send_msg "$chat" "Workspace next"
      ;;
    prev)
      desktop::gnome_shell_eval "global.workspace_manager.get_workspace_by_index(Math.max(0,global.workspace_manager.get_active_workspace_index()-1)).activate(global.get_current_time())"
      send_msg "$chat" "Workspace prev"
      ;;
    [0-9]*)
      local idx=$(( args - 1 ))
      desktop::gnome_shell_eval "if(${idx}>=0&&${idx}<global.workspace_manager.n_workspaces){global.workspace_manager.get_workspace_by_index(${idx}).activate(global.get_current_time())}"
      send_msg "$chat" "Workspace → ${args}"
      ;;
    *)
      send_msg "$chat" "*Usage:* \`/workspace <next|prev|N>\`"
      ;;
  esac
}

register_command "workspace" "_cmd_workspace" "Switch workspaces"
