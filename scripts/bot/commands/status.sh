#!/usr/bin/env bash
# commands/status.sh — /status — comprehensive system snapshot
##############################################################################

_cmd_status() {
  local chat="$1" args="$2"
  send_msg "$chat" "📊 Gathering system info…"
  send_long "$chat" "$(sys_full_status)"
}

register_command "status" "_cmd_status" "📊 Quick system snapshot"
