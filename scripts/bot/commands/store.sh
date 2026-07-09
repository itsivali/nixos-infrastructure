#!/usr/bin/env bash
# commands/store.sh — /store — Nix store status
##############################################################################

_cmd_store() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  send_msg "$chat" "📦 Checking Nix store…"

  local out="📦 *${HOST}* — Nix Store Status
${sep}
\`\`\`"
  out+="$(run_cmd "echo 'Store Size:'; du -sh /nix/store 2>/dev/null; echo ''; echo 'Derivations:'; ls -d /nix/store/*.drv 2>/dev/null | wc -l; echo ''; echo 'Generations:'; nix-env --list-generations --profile /nix/var/nix/profiles/system 2>/dev/null | tail -5; echo ''; echo 'Free Space:'; df -h / | tail -1" 30)"
  out+="
\`\`\`
${sep}
📦 Store status complete."

  send_long "$chat" "$out"
}

register_command "store" "_cmd_store" "📦 Nix store status"
