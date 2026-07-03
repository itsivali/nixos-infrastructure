#!/usr/bin/env bash
# commands/metrics.sh — /metrics — repository metrics report
##############################################################################

_cmd_metrics() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  send_msg "$chat" "📈 Generating metrics report…"

  local out="📈 *${HOST}* — Repository Metrics
${sep}
\`\`\`"
  out+="$(cd ${REPO_DIR} && ./ivali metrics 2>&1 | sed 's/\x1b\[[0-9;]*m//g')"
  out+="
\`\`\`
${sep}
📊 Metrics complete."

  send_long "$chat" "$out"
}

register_command "metrics" "_cmd_metrics" "📈 Repository metrics report"
