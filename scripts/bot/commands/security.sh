#!/usr/bin/env bash
# commands/security.sh — /security — security scan report
##############################################################################

_cmd_security() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  send_msg "$chat" "🛡️ Running security scan…"

  local out="🛡️ *${HOST}* — Security Scan
${sep}
\`\`\`"
  out+="$(run_cmd "cd ${REPO_DIR} && ./ivali metrics 2>&1 | sed 's/\x1b\[[0-9;]*m//g'" 30)"
  out+="
\`\`\`

*System Security:*
\`\`\`"
  out+="$(run_cmd "echo 'Kernel: \$(uname -r)'; echo 'NixOS: \$(nixos-version 2>/dev/null || echo unknown)'; echo 'Fail2Ban: \$(systemctl is-active fail2ban 2>/dev/null || echo inactive)'; echo 'Firewall: \$(systemctl is-active nftables 2>/dev/null || echo inactive)'; echo 'Tailscale: \$(tailscale status 2>/dev/null | head -1 || echo unknown)'" 15)"
  out+="
\`\`\`
${sep}
🛡️ Scan complete."

  send_long "$chat" "$out"
}

register_command "security" "_cmd_security" "🛡️ Security scan report"
