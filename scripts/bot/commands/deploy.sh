#!/usr/bin/env bash
# commands/deploy.sh — /deploy — nixos-rebuild switch
##############################################################################

_cmd_deploy() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  send_msg "$chat" "🚀 Deploying *${HOST}*…"

  local out="🚀 *${HOST}* — Deploy Output
${sep}
\`\`\`"
  out+="$(run_cmd "cd ${REPO_DIR} && nixos-rebuild switch --flake .#${HOST} --show-trace 2>&1" 600)"
  out+="
\`\`\`
${sep}
🏁 Deploy finished."

  send_long "$chat" "$out"
}

register_command "deploy" "_cmd_deploy" "🚀 nixos-rebuild switch"
