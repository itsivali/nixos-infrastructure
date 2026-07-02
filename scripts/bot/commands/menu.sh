#!/usr/bin/env bash
# commands/menu.sh — /menu — Show the command menu
##############################################################################

_cmd_menu() {
  local chat="$1" args="$2"
  send_msg "$chat" "$(generate_menu)"
}

register_command "menu" "_cmd_menu" "📋 Show command menu"
