#!/run/current-system/sw/bin/bash
# bot.sh — Telegram Bot Control Plane v2
#
# Modular dispatcher for NixOS infrastructure management.
# All business logic lives in lib/ and commands/.
# This file only handles: config → source → register → loop → dispatch.
#
set -Euo pipefail

BOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Configuration ──────────────────────────────────────────────────────────
source "${BOT_DIR}/config.sh"

# ── Core libraries ─────────────────────────────────────────────────────────
source "${BOT_DIR}/lib/core.sh"
source "${BOT_DIR}/lib/telegram.sh"
source "${BOT_DIR}/lib/registry.sh"
source "${BOT_DIR}/lib/pending.sh"
source "${BOT_DIR}/lib/auth.sh"

# ── Domain libraries ───────────────────────────────────────────────────────
source "${BOT_DIR}/lib/desktop.sh"
source "${BOT_DIR}/lib/app_registry.sh"
source "${BOT_DIR}/lib/gitlab.sh"
source "${BOT_DIR}/lib/nix.sh"
source "${BOT_DIR}/lib/system.sh"

# ── Desktop subsystem ─────────────────────────────────────────────────────
source "${BOT_DIR}/desktop/discovery.sh"
source "${BOT_DIR}/desktop/aliases.sh"
source "${BOT_DIR}/desktop/urls.sh"

# ── Load all commands (each calls register_command) ────────────────────────
for cmd_file in "${BOT_DIR}/commands/"*.sh; do
  [[ -f "$cmd_file" ]] || continue
  [[ "$(basename "$cmd_file")" == "_template.sh" ]] && continue
  source "$cmd_file"
done

# ── Graceful shutdown ─────────────────────────────────────────────────────
_shutdown() {
  log "Bot shutting down (signal caught)"
  exit 0
}
trap _shutdown SIGTERM SIGINT

# ── Ensure state directory exists ──────────────────────────────────────────
mkdir -p "$STATE_DIR"

# ── Register commands with Telegram API ────────────────────────────────────
log "Bot starting — host=${HOST} chat=${CHAT_ID}"
log "Registered commands: ${_CMD_ORDER[*]}"
register_commands_api

# ── Main event loop ───────────────────────────────────────────────────────
OFFSET="$(cat "$OFFSET_FILE" 2>/dev/null || echo 0)"

while true; do
  updates="$(curl -fsSL --max-time 65 "${API}/getUpdates" \
    -d "offset=${OFFSET}" \
    -d "timeout=60" \
    -d "allowed_updates=[\"message\",\"callback_query\"]" 2>/dev/null || true)"

  if [[ -z "$updates" ]]; then
    sleep 5
    continue
  fi

  while read -r item; do
    uid="$(echo "$item" | jq -r '.update_id')"
    msg="$(echo "$item" | jq -r '.message // empty')"
    cb="$(echo "$item" | jq -r '.callback_query // empty')"

    # Handle callback queries (inline keyboard button presses)
    if [[ -n "$cb" && "$cb" != "null" ]]; then
      OFFSET=$((uid + 1))
      save_offset "$OFFSET"
      cb_id="$(echo "$cb" | jq -r '.id')"
      cb_chat="$(echo "$cb" | jq -r '.message.chat.id // empty')"
      cb_data="$(echo "$cb" | jq -r '.data // empty')"
      if [[ -n "$cb_chat" && "$cb_chat" == "$CHAT_ID" && -n "$cb_data" ]]; then
        log "Callback: ${cb_data}"
        dispatch_callback "$cb_id" "$cb_chat" "$cb_data"
      fi
      continue
    fi

    # Regular messages only
    if [[ -z "$msg" || "$msg" == "null" ]]; then
      OFFSET=$((uid + 1))
      save_offset "$OFFSET"
      continue
    fi

    text="$(echo "$msg" | jq -r '.text // empty')"
    chat="$(echo "$msg" | jq -r '.chat.id // empty')"
    msg_date="$(echo "$msg" | jq -r '.date // 0')"

    OFFSET=$((uid + 1))
    save_offset "$OFFSET"

    if [[ -z "$text" || "$text" == "null" ]]; then
      continue
    fi

    # Skip stale messages to prevent re-executing old commands after restart
    if ! is_recent "$msg_date"; then
      log "Skipping stale message (age: $(( $(date +%s) - msg_date ))s): ${text:0:40}"
      continue
    fi

    # Authorization check
    if [[ "$chat" != "$CHAT_ID" ]]; then
      log "Unauthorized chat: $chat"
      continue
    fi

    # Parse command and args
    if [[ "$text" =~ ^/([a-zA-Z]+)([[:space:]]+(.*))?$ ]]; then
      cmd="${BASH_REMATCH[1]}"
      args="${BASH_REMATCH[3]:-}"
      log "Command: /${cmd} ${args}"
      dispatch "$cmd" "$chat" "$args"
    fi
  done < <(echo "$updates" | jq -c '.result[]' 2>/dev/null)
done
