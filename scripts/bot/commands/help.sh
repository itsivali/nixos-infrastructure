#!/usr/bin/env bash
# commands/help.sh — /help — Full command menu
##############################################################################

_cmd_help() {
  local chat="$1" args="$2"
  send_msg "$chat" "$(generate_menu)"
}

register_command "help" "_cmd_help" "ℹ️ Show this menu"
