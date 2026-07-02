#!/usr/bin/env bash
# commands/gc.sh — /gc — nix store garbage collect
##############################################################################

_cmd_gc() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  send_msg "$chat" "🧹 Running garbage collector…"

  local out="🧹 *${HOST}* — GC Results
${sep}
\`\`\`"
  out+="$(run_cmd "nix store gc 2>&1" 600)"
  out+="
\`\`\`
${sep}
✨ Store cleaned."

  send_long "$chat" "$out"
}

register_command "gc" "_cmd_gc" "🧹 Nix store garbage collect"
