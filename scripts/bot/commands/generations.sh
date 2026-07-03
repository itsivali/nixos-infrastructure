#!/usr/bin/env bash
# commands/generations.sh — /generations — list NixOS generations
##############################################################################

_cmd_generations() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  send_msg "$chat" "📋 Listing NixOS generations…"

  local out="📋 *${HOST}* — NixOS Generations
${sep}
\`\`\`"
  out+="$(run_cmd "nix-env --list-generations --profile /nix/var/nix/profiles/system 2>/dev/null" 15)"
  out+="
\`\`\`

*Current:* \$(nix-env --list-generations --profile /nix/var/nix/profiles/system 2>/dev/null | tail -1 | awk '{print \$1}')
*Total:* \$(nix-env --list-generations --profile /nix/var/nix/profiles/system 2>/dev/null | wc -l)
${sep}
📋 Generations listed."

  send_long "$chat" "$out"
}

register_command "generations" "_cmd_generations" "📋 List NixOS generations"
