#!/usr/bin/env bash
# commands/start.sh — /start — Greet and show persistent keyboard menu
##############################################################################

_cmd_start() {
  local chat="$1" args="$2"
  send_keyboard "$chat" "$(generate_menu)" \
    "/status" "/deploy" "/open" "/apps" \
    "/reboot" "/shutdown" "/gc" "/gitlab" \
    "/help" "/menu" "/run" "/screenshot"
}

register_command "start" "_cmd_start" "ℹ️ Show this menu"
