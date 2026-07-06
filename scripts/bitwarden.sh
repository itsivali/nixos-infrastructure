#!/usr/bin/env bash
# scripts/bitwarden.sh
#
# Bitwarden CLI wrapper for script/service consumption.
# Reads credentials from SOPS-decrypted files in /run/secrets/.
# Session stored in $XDG_RUNTIME_DIR/bitwarden/session (tmpfs, RAM-only).
#
# Usage: bitwarden.sh <command> [args]
#
# Commands:
#   unlock       Unlock vault and cache session
#   lock         Lock vault and clear cache
#   logout       Logout and clear everything
#   status       Show bw status (JSON)
#   sync         Sync vault and invalidate cache
#   doctor       Verify installation
#   session      Print cached session
#   cache        Cache management (update|get|invalidate)
#   get <id>     Get item by id
#   find <query> Search items (JSON)
#   copy <id> <field>  Copy field from item to clipboard
#
set -euo pipefail

# ─── Paths ──────────────────────────────────────────────────────────────────
BW_RT_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bitwarden"
SESSION_FILE="$BW_RT_DIR/session"
CACHE_FILE="$BW_RT_DIR/cache.json"
CACHE_TIME="$BW_RT_DIR/cache-time"
SOPS_DIR="/run/secrets"

mkdir -p "$BW_RT_DIR"

# ─── Helpers ────────────────────────────────────────────────────────────────
status_json() { bw status 2>/dev/null || echo '{"status":"unknown"}'; }
status_field() { status_json | jq -r ".$1" 2>/dev/null || echo "unknown"; }

load_session() {
  [[ -f "$SESSION_FILE" ]] || return 1
  export BW_SESSION="$(<"$SESSION_FILE")"
}

save_session() {
  printf '%s' "$BW_SESSION" > "$SESSION_FILE"
  chmod 600 "$SESSION_FILE"
}

read_sops() {
  local path="$SOPS_DIR/$1"
  if [[ -f "$path" ]]; then
    cat "$path"
  else
    echo ""
  fi
}

# ─── Commands ───────────────────────────────────────────────────────────────
unlock() {
  local clientId clientSecret password
  clientId=$(read_sops bitwarden_clientid)
  clientSecret=$(read_sops bitwarden_clientsecret)
  password=$(read_sops bitwarden_password)

  if [[ -z "$clientId" ]] || [[ -z "$clientSecret" ]]; then
    echo "Error: SOPS credentials not found" >&2
    echo "Run: sudo nixos-rebuild switch" >&2
    exit 1
  fi

  export BW_CLIENTID="$clientId"
  export BW_CLIENTSECRET="$clientSecret"

  local bw_status
  bw_status=$(status_field status)

  case "$bw_status" in
    "unlocked")
      if load_session; then
        echo "Vault already unlocked."
        return 0
      fi
      ;;
    "unauthenticated")
      bw login --apikey > /dev/null 2>&1 || true
      ;;
    "locked")
      ;;
    "error")
      echo "Error: Cannot connect to Bitwarden server" >&2
      exit 1
      ;;
  esac

  local session
  if [[ -n "$password" ]]; then
    session=$(BW_PASSWORD="$password" bw unlock --passwordenv BW_PASSWORD --raw 2>/dev/null)
  else
    session=$(bw unlock --raw 2>/dev/null)
  fi

  unset BW_PASSWORD 2>/dev/null || true

  if [[ -z "$session" ]]; then
    echo "Error: Failed to unlock vault" >&2
    exit 1
  fi

  export BW_SESSION="$session"
  save_session
  echo "Vault unlocked."
}

lock() {
  bw lock > /dev/null 2>&1 || true
  rm -f "$SESSION_FILE"
  unset BW_SESSION 2>/dev/null || true
  echo "Vault locked."
}

logout() {
  bw logout > /dev/null 2>&1 || true
  rm -f "$SESSION_FILE" "$CACHE_FILE" "$CACHE_TIME" 2>/dev/null
  unset BW_SESSION 2>/dev/null || true
  echo "Logged out."
}

sync_bw() {
  load_session || true
  bw sync 2>/dev/null
  rm -f "$CACHE_FILE" "$CACHE_TIME" 2>/dev/null
  echo "Vault synced."
}

doctor() {
  command -v bw >/dev/null || { echo "Missing: bw"; exit 1; }
  command -v jq >/dev/null || { echo "Missing: jq"; exit 1; }

  echo "Status: $(status_field status)"
  [[ -f "$SESSION_FILE" ]] && echo "Cached session: yes" || echo "Cached session: no"
  [[ -f "$CACHE_FILE" ]] && echo "Vault cache: yes" || echo "Vault cache: no"
}

get_item() {
  load_session || true
  bw get item "$1" 2>/dev/null
}

cache_get() {
  if [[ -f "$CACHE_TIME" ]] && [[ -f "$CACHE_FILE" ]]; then
    local age
    age=$(( $(date +%s) - $(<"$CACHE_TIME") ))
    if [[ "$age" -lt "${CACHE_TTL:-300}" ]]; then
      cat "$CACHE_FILE"
      return 0
    fi
  fi

  load_session || true
  local items
  items=$(bw list items 2>/dev/null)
  if [[ $? -eq 0 ]] && [[ -n "$items" ]]; then
    printf '%s' "$items" > "$CACHE_FILE"
    date +%s > "$CACHE_TIME"
    echo "$items"
  else
    echo "Error: Failed to fetch items" >&2
    return 1
  fi
}

cache_invalidate() {
  rm -f "$CACHE_FILE" "$CACHE_TIME" 2>/dev/null
  echo "Cache invalidated."
}

find_items() {
  local query="${1:-}"
  load_session || true

  local items
  items=$(bw list items 2>/dev/null)

  if [[ -z "$items" ]]; then
    echo "Error: No items found" >&2
    return 1
  fi

  if [[ -n "$query" ]]; then
    echo "$items" | jq -r --arg q "$query" \
      '[.[] | select(.name | test($q; "i"))] | .[] | {id, name, username: .login.username}'
  else
    echo "$items" | jq -r '.[] | {id, name, username: .login.username}'
  fi
}

copy_field() {
  local item_id="$1"
  local field="$2"

  if [[ -z "$item_id" ]]; then
    echo "Error: No item specified" >&2
    return 1
  fi

  load_session || true
  local value

  case "$field" in
    username)
      value=$(bw get item "$item_id" 2>/dev/null | jq -r '.login.username // empty')
      ;;
    password)
      value=$(bw get password "$item_id" 2>/dev/null)
      ;;
    uri)
      value=$(bw get item "$item_id" 2>/dev/null | jq -r '.login.uris[0].uri // empty')
      ;;
    notes)
      value=$(bw get item "$item_id" 2>/dev/null | jq -r '.notes // empty')
      ;;
    totp)
      value=$(bw get totp "$item_id" 2>/dev/null)
      ;;
    *)
      echo "Error: Unknown field '$field'" >&2
      return 1
      ;;
  esac

  if [[ -z "$value" ]]; then
    echo "Error: No $field found for item" >&2
    return 1
  fi

  # Copy to clipboard
  if [[ -n "$WAYLAND_DISPLAY" ]]; then
    echo -n "$value" | wl-copy
  elif [[ -n "$DISPLAY" ]]; then
    echo -n "$value" | xclip -selection clipboard
  else
    echo "$value"
    return 0
  fi

  echo "$field copied to clipboard."
}

# ─── Main ───────────────────────────────────────────────────────────────────
case "${1:-help}" in
  unlock)   unlock ;;
  lock)     lock ;;
  logout)   logout ;;
  status)   status_json | jq '.' ;;
  sync)     sync_bw ;;
  doctor)   doctor ;;
  session)  load_session && echo "$BW_SESSION" ;;
  cache)
    case "${2:-get}" in
      update)     load_session || true; cache_get ;;
      get)        cache_get ;;
      invalidate) cache_invalidate ;;
      *)          echo "Usage: $0 cache {update|get|invalidate}" ;;
    esac
    ;;
  get)
    [[ $# -ge 2 ]] || { echo "Usage: $0 get <item-id>"; exit 1; }
    get_item "$2"
    ;;
  find)
    find_items "${2:-}"
    ;;
  copy)
    [[ $# -ge 3 ]] || { echo "Usage: $0 copy <item-id> <field>"; exit 1; }
    copy_field "$2" "$3"
    ;;
  clear)
    rm -f "$SESSION_FILE"
    echo "Session cache cleared."
    ;;
  help|*)
    cat <<'EOF'
Usage: bitwarden.sh <command> [args]

Commands:
  unlock                  Unlock vault and cache session
  lock                    Lock vault and clear cache
  logout                  Logout and clear everything
  status                  Show bw status (JSON)
  sync                    Sync vault and invalidate cache
  doctor                  Verify installation
  session                 Print cached session
  cache {update|get|inval}  Manage vault cache
  get <item-id>           Get item details (JSON)
  find [query]            Search items (JSON)
  copy <item-id> <field>  Copy field (username|password|uri|notes|totp)
  clear                   Remove cached session
EOF
    ;;
esac
