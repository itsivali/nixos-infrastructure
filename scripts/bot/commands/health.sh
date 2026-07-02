#!/usr/bin/env bash
# commands/health.sh — /health — full deployment health check
##############################################################################

_cmd_health() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  send_msg "$chat" "🩺 Running health checks…"

  local out="🩺 *${HOST}* — Health Report
${sep}
\`\`\`"
  out+="$(run_cmd "cd ${REPO_DIR} && scripts/deployment-health.sh 2>&1" 60)"
  out+="
\`\`\`
${sep}
✅ Check complete."

  send_long "$chat" "$out"
}

register_command "health" "_cmd_health" "🩺 Full deployment health check"
