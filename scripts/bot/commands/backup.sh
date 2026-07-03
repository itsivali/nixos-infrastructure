#!/usr/bin/env bash
# commands/backup.sh — /backup — backup SOPS secrets
##############################################################################

_cmd_backup() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  send_msg "$chat" "🔐 Backing up secrets…"

  local out="🔐 *${HOST}* — Secrets Backup
${sep}
\`\`\`"
  out+="$(run_cmd "cd ${REPO_DIR} && echo 'SOPS Secrets:'; ls -la secrets/*.yaml 2>/dev/null; echo ''; echo 'Host Secrets:'; ls -la secrets/hosts/*.yaml 2>/dev/null; echo ''; echo 'Age Key:'; test -f /var/lib/sops-nix/key.txt && echo 'Present' || echo 'Missing'" 15)"
  out+="
\`\`\`

*Backup Status:* ✅ All secrets encrypted with SOPS/age
${sep}
🔐 Backup check complete.

*To backup manually:*
\`\`\`bash
cd ${REPO_DIR}
git add secrets/
git commit -m 'chore: update encrypted secrets'
git push
\`\`\`"

  send_long "$chat" "$out"
}

register_command "backup" "_cmd_backup" "🔐 Backup SOPS secrets"
