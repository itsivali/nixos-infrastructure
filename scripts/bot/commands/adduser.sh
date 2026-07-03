#!/usr/bin/env bash
# commands/adduser.sh — /adduser — add or update an authorized user
##############################################################################

_cmd_adduser() {
  local chat="$1" args="$2"
  send_typing "$chat"

  # Parse: /adduser <chat_id> <role> [name]
  local target_id="${args%% *}"
  local rest="${args#* }"
  local role="${rest%% *}"
  local name="${rest#* }"

  # Validation
  if [[ -z "$target_id" || -z "$role" ]]; then
    send_msg "$chat" "❓ *Usage:* \`/adduser <chat_id> <role> [name]\`

*Roles:* owner, admin, user, guest

*Example:*
\`/adduser 123456789 admin "John Doe"\`"
    return
  fi

  if [[ ! "$role" =~ ^(owner|admin|user|guest)$ ]]; then
    send_msg "$chat" "❌ Invalid role: \`$role\`

Valid roles: owner, admin, user, guest"
    return
  fi

  # Default name
  [[ -z "$name" || "$name" == "$role" ]] && name="User $target_id"

  # Add user
  add_authorized_user "$target_id" "$role" "$name"

  send_msg "$chat" "✅ *User Added*

Chat ID: \`$target_id\`
Role: *$role*
Name: $name

The user can now access commands up to their role level."
}

register_command "adduser" "_cmd_adduser" "Add or update an authorized user (owner only)" \
  "*/adduser <chat_id> <role> [name]*
Add a new user or update an existing user's role.

*Roles:*
• \`owner\` — Full access, can manage users
• \`admin\` — Can run destructive commands
• \`user\` — Can run read-only commands
• \`guest\` — Can only view status and help

*Examples:*
\`/adduser 123456789 admin "John Doe"\`
\`/adduser 987654321 user\`"
