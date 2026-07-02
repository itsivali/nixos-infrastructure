#!/usr/bin/env bash
# commands/shutdown.sh — /shutdown — poweroff with 20s grace period
##############################################################################

_cmd_shutdown() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  send_msg "$chat" "⏻ *${HOST}* — Shutdown
${sep}
Shutting down in 20 seconds… send \`/cancel\` to abort.
${sep}"

  pending_set bash -c 'sleep 20 && systemctl poweroff'
}

register_command "shutdown" "_cmd_shutdown" "⏻ Power off the system"
