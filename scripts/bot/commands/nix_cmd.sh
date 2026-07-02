#!/usr/bin/env bash
# commands/nix_cmd.sh — /nix <cmd> — run a nix command
##############################################################################

_cmd_nix_cmd() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  if [[ -z "$args" ]]; then
    send_msg "$chat" "🔧 *Usage:* \`/nix <command>\`
_Example:_ \`/nix flake check\`"
    return
  fi

  local out="🔧 *nix ${args}*
${sep}
\`\`\`"
  out+="$(run_cmd "nix ${args} 2>&1" 300)"
  out+="
\`\`\`"

  send_long "$chat" "$out"
}

register_command "nix" "_cmd_nix_cmd" "🔧 Run a nix command"
