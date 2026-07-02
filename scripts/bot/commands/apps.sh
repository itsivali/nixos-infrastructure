#!/usr/bin/env bash
# commands/apps.sh — /apps — list discovered applications
##############################################################################

_cmd_apps() {
  local chat="$1" args="$2"
  app_registry_load
  send_long "$chat" "$(app_list)"
}

register_command "apps" "_cmd_apps" "📱 List discovered applications"
