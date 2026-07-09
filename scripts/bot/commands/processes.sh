#!/usr/bin/env bash
# commands/processes.sh — /processes — list running processes sorted by memory
##############################################################################

_cmd_processes() {
  local chat="$1" args="$2"
  local sep="\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501"

  local top_procs
  top_procs="$(ps aux --sort=-%mem 2>/dev/null | head -20 | awk 'NR==1 {printf "%-8s %-6s %s\n", "USER", "%MEM", "COMMAND"} NR>1 {printf "%-8s %-6s %s\n", $1, $4, $11}')" || true

  if [[ -z "$top_procs" ]]; then
    send_msg "$chat" "No processes found."
    return
  fi

  local out="*Top Processes by Memory*
${sep}
\`\`\`
${top_procs}
\`\`\`"

  send_long "$chat" "$out"
}

register_command "processes" "_cmd_processes" "Top memory processes"
