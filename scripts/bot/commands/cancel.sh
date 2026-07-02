#!/usr/bin/env bash
# commands/cancel.sh — /cancel — abort pending reboot/shutdown
##############################################################################

_cmd_cancel() {
  local chat="$1" args="$2"
  if pending_cancel; then
    send_msg "$chat" "🛑 Cancelled."
  else
    send_msg "$chat" "ℹ️ No pending reboot/shutdown to cancel."
  fi
}

register_command "cancel" "_cmd_cancel" "🛑 Abort pending reboot/shutdown"
