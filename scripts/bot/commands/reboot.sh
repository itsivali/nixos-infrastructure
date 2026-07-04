#!/usr/bin/env bash
# commands/reboot.sh — /reboot — Reboot with confirmation
##############################################################################

_cmd_reboot() {
  local chat="$1" args="$2"

  # Check for confirmation token
  if [[ "$args" == *"confirm"* ]]; then
    send_msg "$chat" "🔄 Rebooting system in 5 seconds..."
    pending_set bash -c 'sleep 5 && sudo reboot'
    return
  fi

  # Show confirmation with inline keyboard
  local msg="⚠️ *Confirm Reboot*

Are you sure you want to reboot the system?

*Current uptime:* $(uptime | sed 's/.*up //; s/,.*//')

This action will:
• Stop all running services
• Reboot the system
• Take approximately 1-2 minutes"

  send_inline_keyboard "$chat" "$msg" "✅ Yes, reboot:reboot_confirm" "❌ Cancel:reboot_cancel"
}

# Handle callback queries
_cmd_reboot_callback() {
  local chat="$1" callback_id="$2" data="$3"

  case "$data" in
    reboot_confirm)
      answer_callback "$callback_id" "Rebooting..."
      pending_set bash -c 'sleep 5 && sudo reboot'
      send_msg "$chat" "🔄 Rebooting system in 5 seconds..."
      ;;
    reboot_cancel)
      answer_callback "$callback_id" "Reboot cancelled"
      send_msg "$chat" "✅ Reboot cancelled"
      ;;
  esac
}

register_command "reboot" "_cmd_reboot" "🔄 Reboot the system (with confirmation)"
register_callback "reboot_confirm" "_cmd_reboot_callback"
register_callback "reboot_cancel" "_cmd_reboot_callback"
