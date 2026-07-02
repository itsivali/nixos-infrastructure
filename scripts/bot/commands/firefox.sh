#!/usr/bin/env bash
# commands/firefox.sh — /firefox — open Firefox
##############################################################################

_cmd_firefox() {
  local chat="$1" args="$2"
  launch_app "$chat" "firefox"
}

register_command "firefox" "_cmd_firefox" "🦊 Open Firefox"
