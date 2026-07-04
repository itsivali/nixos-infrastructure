#!/usr/bin/env bash
# commands/rollback.sh — /rollback — Rollback to previous generation
##############################################################################

_cmd_rollback() {
  local chat="$1" args="$2"
  send_typing "$chat"

  # Get current generation
  local current_gen
  current_gen=$(nix_current_generation 2>/dev/null || echo "unknown")

  # Get previous generation
  local prev_gen=$((current_gen - 1))

  # Check for confirmation token
  if [[ "$args" == *"confirm"* ]]; then
    send_msg "$chat" "⏪ Rolling back to generation ${prev_gen}..."
    sudo nixos-rebuild switch --rollback 2>/dev/null
    local result=$?
    if [[ $result -eq 0 ]]; then
      send_msg "$chat" "✅ Rollback successful! Now running generation ${prev_gen}"
    else
      send_msg "$chat" "❌ Rollback failed. Check logs with \`/log nixos-rebuild-switch\`"
    fi
    return
  fi

  # Show confirmation with inline keyboard
  local msg="⚠️ *Confirm Rollback*

Are you sure you want to rollback?

*Current generation:* ${current_gen}
*Target generation:* ${prev_gen}

This action will:
• Switch to the previous NixOS generation
• May take a few minutes to complete
• Can be undone with \`/deploy\`"

  send_inline_keyboard "$chat" "$msg" "✅ Yes, rollback:rollback_confirm" "❌ Cancel:rollback_cancel"
}

# Handle callback queries
_cmd_rollback_callback() {
  local chat="$1" callback_id="$2" data="$3"

  case "$data" in
    rollback_confirm)
      answer_callback "$callback_id" "Rolling back..."
      _cmd_rollback "$chat" "confirm"
      ;;
    rollback_cancel)
      answer_callback "$callback_id" "Rollback cancelled"
      send_msg "$chat" "✅ Rollback cancelled"
      ;;
  esac
}

register_command "rollback" "_cmd_rollback" "⏪ Rollback to previous NixOS generation"
register_callback "rollback_confirm" "_cmd_rollback_callback"
register_callback "rollback_cancel" "_cmd_rollback_callback"
