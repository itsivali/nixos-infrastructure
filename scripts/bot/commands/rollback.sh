#!/usr/bin/env bash
# commands/rollback.sh — /rollback — revert to previous generation
##############################################################################

_cmd_rollback() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  send_msg "$chat" "⏪ Rolling back…"

  local out="⏪ *${HOST}* — Rollback
${sep}
\`\`\`"
  out+="$(run_cmd "cd ${REPO_DIR} && scripts/rollback.sh 2>&1" 120)"
  out+="
\`\`\`
${sep}
↩️ Rollback complete."

  send_long "$chat" "$out"
}

register_command "rollback" "_cmd_rollback" "⏪ Revert to previous generation"
