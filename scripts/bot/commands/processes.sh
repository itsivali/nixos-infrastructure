#!/usr/bin/env bash
# commands/processes.sh — /processes — list running GUI applications
##############################################################################

_cmd_processes() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  # Get window titles from wmctrl
  local wins
  wins="$(wmctrl -l -p 2>/dev/null)" || true

  if [[ -z "$wins" ]]; then
    send_msg "$chat" "📋 No GUI processes detected (wmctrl unavailable)."
    return
  fi

  local out="📋 *GUI Processes*
${sep}
\`\`\`"
  out+=$(printf "%-30s %-8s %s\n" "WINDOW" "PID" "COMMAND")
  out+=$'\n'"$(printf '%.0s-' {1..60})"

  while IFS= read -r line; do
    local title pid
    title="$(echo "$line" | awk '{$1=$2=$3=""; print $0}' | sed 's/^ *//' | cut -c1-30)"
    pid="$(echo "$line" | awk '{print $3}')"
    local cmd
    cmd="$(ps -p "$pid" -o comm= 2>/dev/null || echo "?")"
    out+=$'\n'"$(printf "%-30s %-8s %s" "$title" "$pid" "$cmd")"
  done <<< "$wins"

  out+="
\`\`\`"

  send_long "$chat" "$out"
}

register_command "processes" "_cmd_processes" "📋 List GUI processes"
