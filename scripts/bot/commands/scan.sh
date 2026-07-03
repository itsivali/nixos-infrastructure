#!/usr/bin/env bash
# commands/scan.sh — /scan — security scan
##############################################################################

_cmd_scan() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  send_msg "$chat" "🔒 Running security scan…"

  local out="🔒 *${HOST}* — Security Scan
${sep}
\`\`\`"
  out+="$(cd ${REPO_DIR} && ./ivali doctor 2>&1 | sed 's/\x1b\[[0-9;]*m//g')"
  out+="
\`\`\`
${sep}
🛡️ Security scan complete."

  send_long "$chat" "$out"
}

register_command "scan" "_cmd_scan" "🔒 Security scan"
