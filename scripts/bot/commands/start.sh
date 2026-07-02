#!/usr/bin/env bash
# commands/start.sh — /start — Greet and show help
##############################################################################

_cmd_start() {
  local chat="$1" args="$2"
  send_msg "$chat" "$(generate_menu)"
}

register_command "start" "_cmd_start" "ℹ️ Show this menu"
