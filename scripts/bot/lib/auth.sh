#!/usr/bin/env bash
# lib/auth.sh — Role-based authorization system
#
# Dependencies: none
# Provides:     check_permission, get_user_role, add_authorized_user
##############################################################################

# Role hierarchy:
# - owner: Full access, can manage users
# - admin: Can run destructive commands
# - user: Can run read-only commands
# - guest: Can only view status

# Authorization check
# Usage: if ! check_permission "$chat_id" "admin"; then return; fi
check_permission() {
  local chat_id="$1"
  local required_role="$2"
  
  local user_role
  user_role=$(get_user_role "$chat_id")
  
  case "$required_role" in
    owner)
      [[ "$user_role" == "owner" ]]
      ;;
    admin)
      [[ "$user_role" == "owner" || "$user_role" == "admin" ]]
      ;;
    user)
      [[ "$user_role" == "owner" || "$user_role" == "admin" || "$user_role" == "user" ]]
      ;;
    guest)
      [[ "$user_role" == "owner" || "$user_role" == "admin" || "$user_role" == "user" || "$user_role" == "guest" ]]
      ;;
    *)
      return 1
      ;;
  esac
}

# Get user role
# Usage: role=$(get_user_role "$chat_id")
get_user_role() {
  local chat_id="$1"
  local auth_file="${STATE_DIR}/auth.json"
  
  # If no auth file, everyone is owner (single-user mode)
  if [[ ! -f "$auth_file" ]]; then
    echo "owner"
    return
  fi
  
  # Look up user role
  local role
  role=$(jq -r ".users[\"$chat_id\"].role // \"guest\"" "$auth_file" 2>/dev/null || echo "guest")
  echo "$role"
}

# Add or update authorized user
# Usage: add_authorized_user "$chat_id" "admin" "Willis"
add_authorized_user() {
  local chat_id="$1"
  local role="$2"
  local name="${3:-Unknown}"
  local auth_file="${STATE_DIR}/auth.json"
  
  # Create auth file if it doesn't exist
  if [[ ! -f "$auth_file" ]]; then
    mkdir -p "$(dirname "$auth_file")"
    echo '{"users":{}}' > "$auth_file"
  fi
  
  # Add user
  local tmp=$(mktemp)
  jq --arg id "$chat_id" --arg role "$role" --arg name "$name" \
    '.users[$id] = {"role": $role, "name": $name, "added": now | todate}' \
    "$auth_file" > "$tmp" && mv "$tmp" "$auth_file"
  
  log "Added user: $chat_id ($role) - $name"
}

# Remove authorized user
# Usage: remove_authorized_user "$chat_id"
remove_authorized_user() {
  local chat_id="$1"
  local auth_file="${STATE_DIR}/auth.json"
  
  if [[ -f "$auth_file" ]]; then
    local tmp=$(mktemp)
    jq --arg id "$chat_id" 'del(.users[$id])' "$auth_file" > "$tmp" && mv "$tmp" "$auth_file"
    log "Removed user: $chat_id"
  fi
}

# List all authorized users
# Usage: list_authorized_users
list_authorized_users() {
  local auth_file="${STATE_DIR}/auth.json"
  
  if [[ ! -f "$auth_file" ]]; then
    echo "No users configured"
    return
  fi
  
  jq -r '.users | to_entries[] | "\(.key) (\(.value.role)) - \(.value.name)"' "$auth_file" 2>/dev/null || echo "No users configured"
}

# Check if user is owner
# Usage: if is_owner "$chat_id"; then ... fi
is_owner() {
  local chat_id="$1"
  [[ "$(get_user_role "$chat_id")" == "owner" ]]
}

# Check if user is admin or higher
# Usage: if is_admin "$chat_id"; then ... fi
is_admin() {
  local chat_id="$1"
  local role=$(get_user_role "$chat_id")
  [[ "$role" == "owner" || "$role" == "admin" ]]
}

# Require specific role or send error
# Usage: require_role "$chat_id" "admin" || return
require_role() {
  local chat_id="$1"
  local required_role="$2"
  
  if ! check_permission "$chat_id" "$required_role"; then
    local user_role=$(get_user_role "$chat_id")
    send_msg "$chat_id" "❌ *Permission Denied*

Required role: *${required_role}*
Your role: *${user_role}*

Contact the system owner to request access."
    return 1
  fi
  return 0
}

# Command role mappings
declare -A _CMD_ROLES

# Register command with required role
# Usage: register_command_role "deploy" "admin"
register_command_role() {
  local cmd="$1"
  local role="$2"
  _CMD_ROLES["$cmd"]="$role"
}

# Get command required role
# Usage: role=$(get_command_role "deploy")
get_command_role() {
  local cmd="$1"
  echo "${_CMD_ROLES[$cmd]:-user}"
}

# Initialize default role mappings
_init_default_roles() {
  # Owner only
  register_command_role "adduser" "owner"
  register_command_role "rmuser" "owner"
  register_command_role "users" "owner"
  
  # Admin only (destructive)
  register_command_role "deploy" "admin"
  register_command_role "rollback" "admin"
  register_command_role "reboot" "admin"
  register_command_role "shutdown" "admin"
  register_command_role "update" "admin"
  register_command_role "gc" "admin"
  register_command_role "run" "admin"
  register_command_role "nix" "admin"
  register_command_role "gitlab" "admin"
  
  # User level (read-only)
  register_command_role "status" "user"
  register_command_role "health" "user"
  register_command_role "metrics" "user"
  register_command_role "log" "user"
  register_command_role "processes" "user"
  register_command_role "security" "user"
  register_command_role "scan" "user"
  register_command_role "backup" "user"
  register_command_role "generations" "user"
  register_command_role "store" "user"
  register_command_role "doctor" "user"
  
  # Guest level
  register_command_role "start" "guest"
  register_command_role "help" "guest"
  register_command_role "menu" "guest"

  # Desktop commands (user level — require graphical session)
  register_command_role "open" "user"
  register_command_role "apps" "user"
  register_command_role "firefox" "user"
  register_command_role "screenshot" "user"
  register_command_role "clipboard" "user"
  register_command_role "volume" "user"
  register_command_role "mute" "user"
  register_command_role "unmute" "user"
  register_command_role "brightness" "user"
  register_command_role "notify" "user"
  register_command_role "windows" "user"
  register_command_role "focus" "user"
  register_command_role "close" "user"
  register_command_role "workspace" "user"
  register_command_role "lock" "user"
  register_command_role "logout" "user"
  register_command_role "suspend" "user"
  register_command_role "hibernate" "user"
  register_command_role "monitoroff" "user"
  register_command_role "monitoron" "user"

  # New capabilities (user level)
  register_command_role "pkg" "user"
  register_command_role "speedtest" "user"
  register_command_role "disk" "user"
  register_command_role "top" "user"

  # Misc commands
  register_command_role "git" "user"
  register_command_role "github" "user"
  register_command_role "cancel" "user"
  register_command_role "m" "user"
}

# Initialize default roles on source
_init_default_roles
