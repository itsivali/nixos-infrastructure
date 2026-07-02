#!/usr/bin/env bash
# commands/menu.sh — /menu — Show the command menu with persistent keyboard
##############################################################################

_cmd_menu() {
  local chat="$1" args="$2"
  send_keyboard "$chat" "$(generate_menu)" \
    "/status" "/deploy" "/open" "/apps" \
    "/reboot" "/shutdown" "/gc" "/gitlab" \
    "/help" "/menu" "/run" "/screenshot"
}

register_command "menu" "_cmd_menu" "📋 Show command menu"
