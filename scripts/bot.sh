#!/run/current-system/sw/bin/bash
# bot.sh — Telegram Bot Control Plane
#
# Long-polling Telegram bot for NixOS infrastructure management.
# Reads secrets from /run/secrets/ (telegram_bot_token, telegram_chat_id).
set -Euo pipefail

BOT_TOKEN="$(cat /run/secrets/telegram_bot_token 2>/dev/null || true)"
CHAT_ID="$(cat /run/secrets/telegram_chat_id 2>/dev/null || true)"
HOST="${HOST_NAME:-$(hostname)}"
REPO_DIR="${REPO_DIR:-/home/ivali/nixos-infrastructure}"
OFFSET=0
API="https://api.telegram.org/bot${BOT_TOKEN}"

if [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]]; then
  echo "bot.sh: missing telegram secrets" >&2
  exit 1
fi

log() { echo "[$(date -Iseconds)] $*"; }

send_msg() {
  local chat="$1" text="$2"
  curl -fsSL --max-time 10 -X POST "${API}/sendMessage" \
    -d "chat_id=${chat}" \
    --data-urlencode "text=${text}" \
    -d "parse_mode=Markdown" \
    -d "disable_web_page_preview=true" \
    > /dev/null 2>&1 || true
}

run_cmd() {
  local timeout="${2:-120}"
  local out
  out="$(timeout "$timeout" bash -c "$1" 2>&1)" || true
  echo "$out"
}

send_reply() {
  local chat="$1" msg="$2"
  local max_len=4000
  if [[ ${#msg} -gt $max_len ]]; then
    send_msg "$chat" "${msg:0:$max_len}..."
    send_msg "$chat" "(truncated — full output in journalctl)"
  else
    send_msg "$chat" "$msg"
  fi
}

handle_command() {
  local chat="$1" cmd="$2" args="$3"

  if [[ "$chat" != "$CHAT_ID" ]]; then
    log "Unauthorized chat: $chat"
    return
  fi

  log "Command: /${cmd} ${args}"

  case "$cmd" in
    start|help)
      send_msg "$chat" "*${HOST} — Bot Control Plane*"
      send_msg "$chat" "\
\`/deploy\`  — nixos-rebuild switch
\`/status\` — system status summary
\`/health\` — full deployment health check
\`/update\` — git pull + flake update + push
\`/rollback\` — revert to previous generation
\`/gc\`     — nix store garbage collect
\`/reboot\` — reboot the system
\`/log\`    — last 50 journal lines
\`/git\`    — run a git command
\`/nix\`    — run a nix command
\`/help\`   — this message"
      ;;

    status)
      local out
      out="*${HOST} — Status*"
      out+="\`\`\`"
      out+="$(run_cmd "uname -a 2>&1; echo '---'; df -h / --output=size,used,avail,pcent 2>&1 | tail -1; echo '---'; nixos-rebuild list-generations 2>&1 | tail -3; echo '---'; uptime -p 2>&1")"
      out+="\`\`\`"
      send_reply "$chat" "$out"
      ;;

    health)
      send_msg "$chat" "Running health checks..."
      local out
      out="*${HOST} — Health*\`\`\`"
      out+="$(run_cmd "cd ${REPO_DIR} && scripts/deployment-health.sh 2>&1" 60)"
      out+="\`\`\`"
      send_reply "$chat" "$out"
      ;;

    deploy|rebuild)
      send_msg "$chat" "Deploying ${HOST}..."
      local out
      out="*${HOST} — Deploy*\`\`\`"
      out+="$(run_cmd "cd ${REPO_DIR} && nixos-rebuild switch --flake .#${HOST} --show-trace 2>&1" 600)"
      out+="\`\`\`"
      send_reply "$chat" "$out"
      ;;

    update)
      send_msg "$chat" "Updating flake inputs..."
      local out
      out="*${HOST} — Update*\`\`\`"
      out+="$(run_cmd "cd ${REPO_DIR} && git pull --ff-only origin main 2>&1 && nix flake update 2>&1 && git add flake.lock && git commit -m 'flake update: $(date -Iseconds)' 2>&1 && git push origin main 2>&1" 600)"
      out+="\`\`\`"
      send_reply "$chat" "$out"
      ;;

    rollback)
      send_msg "$chat" "Rolling back..."
      local out
      out="*${HOST} — Rollback*\`\`\`"
      out+="$(run_cmd "cd ${REPO_DIR} && scripts/rollback.sh 2>&1" 120)"
      out+="\`\`\`"
      send_reply "$chat" "$out"
      ;;

    gc)
      send_msg "$chat" "Running garbage collector..."
      local out
      out="*${HOST} — GC*\`\`\`"
      out+="$(run_cmd "nix store gc 2>&1" 600)"
      out+="\`\`\`"
      send_reply "$chat" "$out"
      ;;

    reboot)
      send_msg "$chat" "Rebooting ${HOST} in 10 seconds... Use /cancel to abort."
      sleep 10
      systemctl reboot 2>&1 || send_msg "$chat" "Reboot failed."
      ;;

    log)
      local lines="${args:-50}"
      local out
      out="*${HOST} — Last ${lines} lines*\`\`\`"
      out+="$(run_cmd "journalctl -n ${lines} --no-pager 2>&1" 30)"
      out+="\`\`\`"
      send_reply "$chat" "$out"
      ;;

    git)
      if [[ -z "$args" ]]; then
        send_msg "$chat" "Usage: /git <command>"
        return
      fi
      local out
      out="\`\`\`"
      out+="$(run_cmd "cd ${REPO_DIR} && git ${args} 2>&1" 30)"
      out+="\`\`\`"
      send_reply "$chat" "$out"
      ;;

    nix)
      if [[ -z "$args" ]]; then
        send_msg "$chat" "Usage: /nix <command>"
        return
      fi
      local out
      out="\`\`\`"
      out+="$(run_cmd "nix ${args} 2>&1" 300)"
      out+="\`\`\`"
      send_reply "$chat" "$out"
      ;;

    cancel)
      send_msg "$chat" "Cancelled."
      ;;

    *)
      send_msg "$chat" "Unknown command: /${cmd}. Try /help"
      ;;
  esac
}

log "Bot starting — host=${HOST} chat=${CHAT_ID}"

register_commands() {
  curl -fsSL --max-time 10 -X POST "${API}/setMyCommands" \
    -H "Content-Type: application/json" \
    -d '{"commands":[
      {"command":"deploy","description":"nixos-rebuild switch"},
      {"command":"status","description":"system status summary"},
      {"command":"health","description":"full deployment health check"},
      {"command":"update","description":"git pull + flake update + push"},
      {"command":"rollback","description":"revert to previous generation"},
      {"command":"gc","description":"nix store garbage collect"},
      {"command":"reboot","description":"reboot the system"},
      {"command":"log","description":"last 50 journal lines"},
      {"command":"git","description":"run a git command"},
      {"command":"nix","description":"run a nix command"},
      {"command":"help","description":"show available commands"}
    ]}' > /dev/null 2>&1 || true
}
register_commands

while true; do
  updates="$(curl -fsSL --max-time 65 "${API}/getUpdates" \
    -d "offset=${OFFSET}" \
    -d "timeout=60" \
    -d "allowed_updates=[\"message\"]" 2>/dev/null || true)"

  if [[ -z "$updates" ]]; then
    sleep 5
    continue
  fi

  while read -r item; do
    uid="$(echo "$item" | jq -r '.update_id')"
    msg="$(echo "$item" | jq -r '.message // empty')"

    if [[ -z "$msg" || "$msg" == "null" ]]; then
      OFFSET=$((uid + 1))
      continue
    fi

    text="$(echo "$msg" | jq -r '.text // empty')"
    chat="$(echo "$msg" | jq -r '.chat.id // empty')"

    OFFSET=$((uid + 1))

    if [[ -z "$text" || "$text" == "null" ]]; then
      continue
    fi

    if [[ "$text" =~ ^/([a-zA-Z]+)([[:space:]]+(.*))?$ ]]; then
      cmd="${BASH_REMATCH[1]}"
      args="${BASH_REMATCH[3]:-}"
      handle_command "$chat" "$cmd" "$args"
    fi
  done < <(echo "$updates" | jq -c '.result[]' 2>/dev/null)
done
