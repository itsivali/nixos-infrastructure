#!/usr/bin/env bash
# commands/rmuser.sh — /rmuser — remove an authorized user
##############################################################################

_cmd_rmuser() {
  local chat="$1" args="$2"
  send_typing "$chat"

  local target_id="${args%% *}"

  if [[ -z "$target_id" ]]; then
    send_msg "$chat" "❓ *Usage:* \`/rmuser <chat_id>\`

*Example:*
\`/rmuser 123456789\`"
    return
  fi

  # Check if user exists
  local auth_file="${STATE_DIR}/auth.json"
  if [[ ! -f "$auth_file" ]]; then
    send_msg "$chat" "❌ No users configured."
    return
  fi

  local exists
  exists=$(jq -r ".users[\"$target_id\"] // empty" "$auth_file" 2>/dev/null)
  if [[ -z "$exists" ]]; then
    send_msg "$chat" "❌ User \`$target_id\` not found."
    return
  fi

  remove_authorized_user "$target_id"

  send_msg "$chat" "✅ *User Removed*

Chat ID: \`$target_id\`

The user can no longer access the bot."
}

register_command "rmuser" "_cmd_rmuser" "Remove an authorized user (owner only)" \
  "*/rmuser <chat_id>*
Remove a user from the authorized users list.

*Example:*
\`/rmuser 123456789\`"
