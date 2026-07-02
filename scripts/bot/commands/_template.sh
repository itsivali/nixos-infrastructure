#!/usr/bin/env bash
# commands/_template.sh — Template for new commands
#
# Copy this file to create new commands. The register_command call at the
# bottom automatically adds it to the dispatcher.
##############################################################################

_cmd_template() {
  local chat="$1" args="$2"

  # Your command logic here
  send_msg "$chat" "Hello from template!"
}

# register_command "name" "handler" "short description"
# register_command "template" "_cmd_template" "📝 Template command"
