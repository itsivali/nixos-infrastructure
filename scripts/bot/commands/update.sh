#!/usr/bin/env bash
# commands/update.sh — /update — git pull + flake update + push
##############################################################################

_cmd_update() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  send_msg "$chat" "🔄 Updating flake inputs…"

  # Detect current branch dynamically
  local branch
  branch="$(cd "${REPO_DIR}" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")"

  local out="🔄 *${HOST}* — Flake Update (branch: ${branch})
${sep}
\`\`\`"
  out+="$(run_cmd "cd ${REPO_DIR} && git pull --ff-only origin ${branch} 2>&1 && nix flake update 2>&1 && git add flake.lock && git commit -m 'flake update: $(date -Iseconds)' 2>&1 && git push origin ${branch} 2>&1" 600)"
  out+="
\`\`\`
${sep}
📦 Inputs refreshed & pushed to \`${branch}\`."

  send_long "$chat" "$out"
}

register_command "update" "_cmd_update" "🔄 git pull + flake update + push"
