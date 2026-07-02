#!/usr/bin/env bash
# commands/git_cmd.sh — /git <cmd> — run git in the infra repo
##############################################################################

_cmd_git_cmd() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  if [[ -z "$args" ]]; then
    send_msg "$chat" "🔧 *Usage:* \`/git <command>\`
Runs a git command inside \`${REPO_DIR}\`
_Example:_ \`/git log --oneline -5\`"
    return
  fi

  local out="🔧 *git ${args}*
${sep}
\`\`\`"
  out+="$(run_cmd "cd ${REPO_DIR} && git ${args} 2>&1" 30)"
  out+="
\`\`\`"

  send_long "$chat" "$out"
}

register_command "git" "_cmd_git_cmd" "🔧 Run a git command"
