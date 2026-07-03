#!/usr/bin/env bash
# commands/users.sh — /users — list all authorized users
##############################################################################

_cmd_users() {
  local chat="$1" args="$2"
  send_typing "$chat"

  local auth_file="${STATE_DIR}/auth.json"

  if [[ ! -f "$auth_file" ]]; then
    send_msg "$chat" "👥 *Authorized Users*

_No users configured yet._

*Single-user mode:* All commands are available to everyone.
Use \`/adduser\` to set up role-based access."
    return
  fi

  local user_count
  user_count=$(jq '.users | length' "$auth_file" 2>/dev/null || echo "0")

  if [[ "$user_count" -eq 0 ]]; then
    send_msg "$chat" "👥 *Authorized Users*

_No users configured yet._

Use \`/adduser <chat_id> <role> [name]\` to add users."
    return
  fi

  local out="👥 *Authorized Users* ($user_count)
━━━━━━━━━━━━━━━━━━━━━━━━━━━

"

  # Build user list
  local users
  users=$(jq -r '.users | to_entries[] | "\(.key)|\(.value.role)|\(.value.name)|\(.value.added // "unknown")"' "$auth_file" 2>/dev/null)

  while IFS='|' read -r uid role name added; do
    local emoji
    case "$role" in
      owner) emoji="👑" ;;
      admin) emoji="🔑" ;;
      user)  emoji="👤" ;;
      guest) emoji="👁" ;;
      *)     emoji="❓" ;;
    esac
    out+="${emoji} *${name}*
   Chat: \`$uid\` · Role: *$role*
   Added: ${added}

"
  done <<< "$users"

  out+="━━━━━━━━━━━━━━━━━━━━━━━━━━━
*Roles:*
👑 owner · 🔑 admin · 👤 user · 👁 guest"

  send_msg "$chat" "$out"
}

register_command "users" "_cmd_users" "List all authorized users (owner only)" \
  "*/users*
Show all authorized users with their roles and permissions.

*Roles:*
• 👑 \`owner\` — Full access, can manage users
• 🔑 \`admin\` — Can run destructive commands
• 👤 \`user\` — Can run read-only commands
• 👁 \`guest\` — Can only view status and help"
