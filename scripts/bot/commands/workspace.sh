#!/usr/bin/env bash
# commands/workspace.sh — /workspace next|prev|N — workspace switching
##############################################################################

_cmd_workspace() {
  local chat="$1" args="$2"

  if [[ -z "$args" ]]; then
    send_msg "$chat" "🔧 *Usage:* \`/workspace <next|prev|N>\`
_Switch desktop workspaces._
_Examples:_ \`/workspace next\`, \`/workspace 3\`"
    return
  fi

  local current
  current="$(wmctrl -d 2>/dev/null | awk '/\* /{print $1}')" || true

  case "$args" in
    next)
      if [[ -n "$current" ]]; then
        local next_ws=$(( current + 1 ))
        # Wrap around
        local total
        total="$(wmctrl -d 2>/dev/null | wc -l)" || true
        if (( next_ws >= total )); then
          next_ws=0
        fi
        wmctrl -s "$next_ws" 2>/dev/null
        send_msg "$chat" "🖥 Workspace → ${next_ws}"
      else
        send_msg "$chat" "❌ Could not detect current workspace."
      fi
      ;;
    prev)
      if [[ -n "$current" ]]; then
        local prev_ws=$(( current - 1 ))
        if (( prev_ws < 0 )); then
          local total
          total="$(wmctrl -d 2>/dev/null | wc -l)" || true
          prev_ws=$(( total - 1 ))
        fi
        wmctrl -s "$prev_ws" 2>/dev/null
        send_msg "$chat" "🖥 Workspace → ${prev_ws}"
      else
        send_msg "$chat" "❌ Could not detect current workspace."
      fi
      ;;
    [0-9]*)
      local target="$args"
      wmctrl -s "$target" 2>/dev/null
      send_msg "$chat" "🖥 Workspace → ${target}"
      ;;
    *)
      send_msg "$chat" "🔧 *Usage:* \`/workspace <next|prev|N>\`"
      ;;
  esac
}

register_command "workspace" "_cmd_workspace" "🖥 Switch workspaces"
