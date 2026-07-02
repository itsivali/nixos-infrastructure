#!/usr/bin/env bash
# commands/reboot.sh — /reboot — reboot with 20s grace period
##############################################################################

_cmd_reboot() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  send_msg "$chat" "♻️ *${HOST}* — Reboot
${sep}
Rebooting in 20 seconds… send \`/cancel\` to abort.
${sep}"

  pending_set bash -c 'sleep 20 && systemctl reboot'
}

register_command "reboot" "_cmd_reboot" "♻️ Reboot the system"
