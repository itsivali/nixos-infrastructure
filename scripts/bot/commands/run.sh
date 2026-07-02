#!/usr/bin/env bash
# commands/run.sh — /run <cmd> — execute a shell command
##############################################################################

_cmd_run() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  if [[ -z "$args" ]]; then
    send_msg "$chat" "🖥 *Usage:* \`/run <command>\`
_Executes a shell command on the host._
_Example:_ \`/run fastfetch\`"
    return
  fi

  local out="🖥 *Run:* \`${args}\`
${sep}
\`\`\`"
  out+="$(run_cmd "$args" 120)"
  out+="
\`\`\`"

  send_long "$chat" "$out"
}

register_command "run" "_cmd_run" "🖥 Execute a shell command"
