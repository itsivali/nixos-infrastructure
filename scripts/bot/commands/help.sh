#!/usr/bin/env bash
# commands/help.sh — /help — Full command menu with persistent keyboard
##############################################################################

_cmd_help() {
  local chat="$1" args="$2"
  send_keyboard "$chat" "$(generate_menu)" \
    "/status" "/deploy" "/open" "/apps" \
    "/reboot" "/shutdown" "/gc" "/gitlab" \
    "/help" "/menu" "/run" "/screenshot"
}

register_command "help" "_cmd_help" "ℹ️ Show this menu"
