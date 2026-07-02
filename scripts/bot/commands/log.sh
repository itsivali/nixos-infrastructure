#!/usr/bin/env bash
# commands/log.sh — /log [n] [unit] — journal lines
##############################################################################

_cmd_log() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  local lines="${args%% *}"
  local unit=""
  [[ "$args" == *' '* ]] && unit="${args#* }"
  lines="${lines:-50}"

  if ! [[ "$lines" =~ ^[0-9]+$ ]]; then
    send_msg "$chat" "🔧 *Usage:* \`/log [n] [unit]\`
_n must be a number._ _(default 50)_
_Example:_ \`/log 100 sshd\`"
    return
  fi
  if (( lines > 1000 )); then
    lines=1000
  fi

  local journal_args=(-n "$lines" --no-pager)
  local title="📜 *${HOST}* — Last ${lines} journal lines"
  if [[ -n "$unit" ]]; then
    journal_args+=(-u "$unit")
    title="📜 *${HOST}* — Last ${lines} lines for \`${unit}\`"
  fi

  local raw
  raw="$(timeout 30 journalctl "${journal_args[@]}" 2>&1)" || true
  if [[ -z "$raw" ]]; then
    raw="(no matching journal entries)"
  fi

  local out="${title}
${sep}
\`\`\`"
  out+="${raw}"
  out+="
\`\`\`"
  send_long "$chat" "$out"
}

register_command "log" "_cmd_log" "📜 Last N journal lines"
