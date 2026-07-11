#!/usr/bin/env bash
# commands/top_cmd.sh — /top, /ps — interactive process viewer
##############################################################################

_cmd_top() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  local subcmd="${args%% *}"
  local count=15

  # Parse optional count
  if [[ "$subcmd" =~ ^[0-9]+$ ]]; then
    count="$subcmd"
    subcmd=""
  fi

  local sort_by="mem"
  case "$subcmd" in
    cpu|c) sort_by="cpu" ;;
    mem|m|"") sort_by="mem" ;;
    name|n) sort_by="name" ;;
    pid|p) sort_by="pid" ;;
    *)
      if [[ "$subcmd" =~ ^[0-9]+$ ]]; then
        count="$subcmd"
      fi
      ;;
  esac

  send_typing "$chat"

  local ps_output
  case "$sort_by" in
    cpu)
      ps_output=$(ps aux --sort=-%cpu 2>/dev/null | head -n $((count + 1)))
      ;;
    name)
      ps_output=$(ps aux --sort=+comm 2>/dev/null | head -n $((count + 1)))
      ;;
    pid)
      ps_output=$(ps aux --sort=-pid 2>/dev/null | head -n $((count + 1)))
      ;;
    *)
      ps_output=$(ps aux --sort=-%mem 2>/dev/null | head -n $((count + 1)))
      ;;
  esac

  if [[ -z "$ps_output" ]]; then
    send_msg "$chat" "No processes found."
    return
  fi

  # Count total processes
  local total_procs
  total_procs=$(ps aux 2>/dev/null | wc -l)
  total_procs=$((total_procs - 1))

  # System load
  local load_info
  load_info=$(uptime 2>/dev/null | awk -F'load average: ' '{print $2}' | xargs)

  # Memory summary
  local mem_info
  mem_info=$(free -h 2>/dev/null | awk '/^Mem:/{printf "%s/%s (%.0f%%)", $3, $2, $3/$2*100}')

  local out="📊 *${HOST}* — Process Viewer
${sep}
_Sorted by:_ \`${sort_by}\` · _Showing top_ \`${count}\`
_Load:_ \`${load_info}\` · _Memory:_ \`${mem_info}\`
${sep}
\`\`\`
${ps_output}
\`\`\`

_Total:_ ${total_procs} processes
${sep}
_Usage:_ \`/top cpu\` \`/top mem\` \`/top 20\`"

  send_long "$chat" "$out"
}

register_command "top" "_cmd_top" "📊 Process viewer (top/ps)"
register_command "ps" "_cmd_top" "📊 Process viewer (alias)"
