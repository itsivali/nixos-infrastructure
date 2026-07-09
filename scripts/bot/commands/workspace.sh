# commands/workspace.sh — /workspace next|prev|N — workspace switching
# Uses hyprctl dispatch for Hyprland workspace control.
##############################################################################

_cmd_workspace() {
  local chat="$1" args="$2"

  if [[ -z "$args" ]]; then
    send_msg "$chat" "*Usage:* \`/workspace <next|prev|N>\`
_Switch Hyprland workspaces._
_Examples:_ \`/workspace next\`, \`/workspace 3\`"
    return
  fi

  desktop::require_graphical "$chat" || return

  case "$args" in
    next)
      desktop::hyprctl_call dispatch workspace +1 >/dev/null 2>&1
      send_msg "$chat" "Workspace next"
      ;;
    prev)
      desktop::hyprctl_call dispatch workspace -1 >/dev/null 2>&1
      send_msg "$chat" "Workspace prev"
      ;;
    [0-9]*)
      desktop::hyprctl_call dispatch workspace "$args" >/dev/null 2>&1
      send_msg "$chat" "Workspace → ${args}"
      ;;
    *)
      send_msg "$chat" "*Usage:* \`/workspace <next|prev|N>\`"
      ;;
  esac
}

register_command "workspace" "_cmd_workspace" "Switch workspaces"
