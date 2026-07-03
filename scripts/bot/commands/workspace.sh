#!/usr/bin/env bash
# commands/workspace.sh — /workspace next|prev|N — workspace switching
# Uses GNOME Shell DBus API (works natively on Wayland)
##############################################################################

_cmd_workspace() {
  local chat="$1" args="$2"

  if [[ -z "$args" ]]; then
    send_msg "$chat" "🔧 *Usage:* \`/workspace <next|prev|N>\`
_Switch desktop workspaces._
_Examples:_ \`/workspace next\`, \`/workspace 3\`"
    return
  fi

  # Get current workspace index via GNOME Shell DBus
  local current
  current="$(gdbus call --session \
    --dest org.gnome.Shell \
    --object-path /org/gnome/Shell \
    --method org.gnome.Shell.Eval \
    'global.workspace_manager.get_active_workspace_index()' 2>/dev/null)" || true
  current="$(echo "$current" | grep -oP '\d+')"

  case "$args" in
    next)
      if [[ -n "$current" ]]; then
        local next_ws=$(( current + 1 ))
        local total
        total="$(gdbus call --session \
          --dest org.gnome.Shell \
          --object-path /org/gnome/Shell \
          --method org.gnome.Shell.Eval \
          'global.workspace_manager.get_n_workspaces()' 2>/dev/null)" || true
        total="$(echo "$total" | grep -oP '\d+')"
        if [[ -n "$total" ]] && (( next_ws >= total )); then
          next_ws=0
        fi
        gdbus call --session \
          --dest org.gnome.Shell \
          --object-path /org/gnome/Shell \
          --method org.gnome.Shell.Eval \
          "global.workspace_manager.get_workspace_by_index(${next_ws}).activate(global.get_current_time())" 2>/dev/null
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
          total="$(gdbus call --session \
            --dest org.gnome.Shell \
            --object-path /org/gnome/Shell \
            --method org.gnome.Shell.Eval \
            'global.workspace_manager.get_n_workspaces()' 2>/dev/null)" || true
          total="$(echo "$total" | grep -oP '\d+')"
          prev_ws=$(( ${total:-1} - 1 ))
        fi
        gdbus call --session \
          --dest org.gnome.Shell \
          --object-path /org/gnome/Shell \
          --method org.gnome.Shell.Eval \
          "global.workspace_manager.get_workspace_by_index(${prev_ws}).activate(global.get_current_time())" 2>/dev/null
        send_msg "$chat" "🖥 Workspace → ${prev_ws}"
      else
        send_msg "$chat" "❌ Could not detect current workspace."
      fi
      ;;
    [0-9]*)
      local target="$args"
      gdbus call --session \
        --dest org.gnome.Shell \
        --object-path /org/gnome/Shell \
        --method org.gnome.Shell.Eval \
        "global.workspace_manager.get_workspace_by_index(${target}).activate(global.get_current_time())" 2>/dev/null
      send_msg "$chat" "🖥 Workspace → ${target}"
      ;;
    *)
      send_msg "$chat" "🔧 *Usage:* \`/workspace <next|prev|N>\`"
      ;;
  esac
}

register_command "workspace" "_cmd_workspace" "🖥 Switch workspaces"
