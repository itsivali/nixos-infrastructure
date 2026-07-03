#!/usr/bin/env bash
# commands/doctor.sh — /doctor — full repository health check
##############################################################################

_cmd_doctor() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  send_msg "$chat" "🔍 Running repository doctor…"

  local out="🔍 *${HOST}* — Doctor Report
${sep}
\`\`\`"
  out+="$(cd ${REPO_DIR} && ./ivali doctor 2>&1 | sed 's/\x1b\[[0-9;]*m//g')"
  out+="
\`\`\`
${sep}
🩺 Doctor complete."

  send_long "$chat" "$out"
}

register_command "doctor" "_cmd_doctor" "🔍 Full repository health check"
