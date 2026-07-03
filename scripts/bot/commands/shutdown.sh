#!/usr/bin/env bash
# commands/shutdown.sh — /shutdown — Power off with confirmation
##############################################################################

_cmd_shutdown() {
  local chat="$1" args="$2"

  # Check for confirmation token
  if [[ "$args" == *"confirm"* ]]; then
    send_msg "$chat" "⏻ Shutting down system in 5 seconds..."
    sleep 5
    sudo shutdown now
    return
  fi

  # Show confirmation with inline keyboard
  local msg="⚠️ *Confirm Shutdown*

Are you sure you want to shut down the system?

*Current uptime:* $(uptime | sed 's/.*up //; s/,.*//')

This action will:
• Stop all running services
• Power off the system
• Requires physical power-on to restart"

  send_inline_keyboard "$chat" "$msg" "✅ Yes, shutdown:shutdown_confirm" "❌ Cancel:shutdown_cancel"
}

# Handle callback queries
_cmd_shutdown_callback() {
  local chat="$1" callback_id="$2" data="$3"

  case "$data" in
    shutdown_confirm)
      answer_callback "$callback_id" "Shutting down..."
      send_msg "$chat" "⏻ Shutting down system in 5 seconds..."
      sleep 5
      sudo shutdown now
      ;;
    shutdown_cancel)
      answer_callback "$callback_id" "Shutdown cancelled"
      send_msg "$chat" "✅ Shutdown cancelled"
      ;;
  esac
}

register_command "shutdown" "_cmd_shutdown" "⏻ Shut down the system (with confirmation)"
