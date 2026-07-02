#!/run/current-system/sw/bin/bash
# bot.sh — Telegram Bot Control Plane
#
# Long-polling Telegram bot for NixOS infrastructure management.
# Reads secrets from /run/secrets/ (telegram_bot_token, telegram_chat_id).
set -Euo pipefail

BOT_TOKEN="$(cat /run/secrets/telegram_bot_token 2>/dev/null || true)"
CHAT_ID="$(cat /run/secrets/telegram_chat_id 2>/dev/null || true)"
GITLAB_TOKEN="$(cat /run/secrets/gitlab_token 2>/dev/null || true)"
HOST="${HOST_NAME:-$(hostname)}"
REPO_DIR="${REPO_DIR:-/home/ivali/nixos-infrastructure}"
GITLAB_URL="${GITLAB_URL:-https://gitlab.com/willisivali/nixos-infrastructure}"
DEFAULT_USER="${DEFAULT_USER:-ivali}"
OFFSET_FILE="/var/lib/ivali-bot/offset"
MAX_AGE_SECONDS="${MAX_AGE_SECONDS:-300}"
OFFSET="$(cat "$OFFSET_FILE" 2>/dev/null || echo 0)"
API="https://api.telegram.org/bot${BOT_TOKEN}"
GITLAB_API="${GITLAB_URL}/api/v4"
GITLAB_PROJECT="willisivali%2Fnixos-infrastructure"

if [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]]; then
  echo "bot.sh: missing telegram secrets" >&2
  exit 1
fi

log() { echo "[$(date -Iseconds)] $*"; }

# Graceful shutdown on SIGTERM/SIGINT
_shutdown() {
  log "Bot shutting down (signal caught)"
  exit 0
}
trap _shutdown SIGTERM SIGINT

# Persist offset to disk so it survives restarts
save_offset() {
  echo "$1" > "${OFFSET_FILE}.tmp" && mv "${OFFSET_FILE}.tmp" "$OFFSET_FILE"
}

# Returns 0 if the given unix timestamp is within MAX_AGE_SECONDS of now
is_recent() {
  local msg_time="$1"
  local now
  now="$(date +%s)"
  (( now - msg_time <= MAX_AGE_SECONDS ))
}

# Track a background action (reboot/shutdown) so /cancel can kill it
_PENDING_PID=""

_pending_action() {
  "$@" 2>/dev/null || true
}

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

gitlab_api() {
  local endpoint="$1"
  local method="${2:-GET}"
  local body="${3:-}"
  local curl_args=(
    -fsSL --max-time 30
    -X "$method"
    -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}"
    -H "Content-Type: application/json"
  )
  if [[ -n "$body" ]]; then
    curl_args+=(-d "$body")
  fi
  curl "${curl_args[@]}" "${GITLAB_API}${endpoint}" 2>&1 || echo '{"error":"GitLab API request failed"}'
}

# Flushes the in-progress chunk buffer for send_long, closing a fenced code
# block first if one is still open so each Telegram message is self-contained.
# Relies on bash dynamic scoping to see _sl_* locals from the send_long call
# that invokes it — do not call this directly outside send_long.
_send_long_flush() {
  if [[ -n "$_sl_chunk" ]]; then
    local out="$_sl_chunk"
    if [[ "$_sl_in_code" -eq 1 ]]; then
      out+=$'\n```'
    fi
    send_msg "$_sl_chat" "$out"
  fi
  if [[ "$_sl_in_code" -eq 1 ]]; then
    _sl_chunk='```'
  else
    _sl_chunk=""
  fi
}

# Splits a long message into Telegram-sized chunks on line boundaries instead
# of blind character offsets, and re-opens/re-closes ``` fences across chunk
# boundaries so a split mid-codeblock never leaves a message half-formatted.
send_long() {
  local _sl_chat="$1" msg="$2"
  local _sl_max="${3:-3500}"
  local _sl_chunk="" _sl_in_code=0
  local line piece candidate toggled

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Hard-split any single line that alone exceeds the chunk size (e.g. a
    # very long nix --show-trace line with no newlines in it).
    while [[ ${#line} -gt $_sl_max ]]; do
      piece="${line:0:$_sl_max}"
      line="${line:$_sl_max}"
      if [[ -z "$_sl_chunk" ]]; then candidate="$piece"; else candidate="${_sl_chunk}"$'\n'"${piece}"; fi
      if [[ ${#candidate} -gt $_sl_max && -n "$_sl_chunk" ]]; then
        _send_long_flush
        if [[ -z "$_sl_chunk" ]]; then candidate="$piece"; else candidate="${_sl_chunk}"$'\n'"${piece}"; fi
      fi
      _sl_chunk="$candidate"
    done

    toggled=0
    [[ "$line" == '```'* ]] && toggled=1

    if [[ -z "$_sl_chunk" ]]; then candidate="$line"; else candidate="${_sl_chunk}"$'\n'"${line}"; fi

    if [[ ${#candidate} -gt $_sl_max && -n "$_sl_chunk" ]]; then
      _send_long_flush
      if [[ -z "$_sl_chunk" ]]; then candidate="$line"; else candidate="${_sl_chunk}"$'\n'"${line}"; fi
    fi
    _sl_chunk="$candidate"

    if [[ $toggled -eq 1 ]]; then
      _sl_in_code=$((1 - _sl_in_code))
    fi
  done <<< "$msg"

  if [[ -n "$_sl_chunk" ]]; then
    send_msg "$_sl_chat" "$_sl_chunk"
  fi
}

handle_command() {
  local chat="$1" cmd="$2" args="$3"

  if [[ "$chat" != "$CHAT_ID" ]]; then
    log "Unauthorized chat: $chat"
    return
  fi

  log "Command: /${cmd} ${args}"

  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  case "$cmd" in
    start|help)
      send_msg "$chat" "🛰 *${HOST}* — Control Plane
${sep}
_NixOS GitOps bot · long-poll session active_
${sep}

🚀 *Deployment*
\`/deploy\`     Apply config — \`nixos-rebuild switch\`
\`/update\`     Pull → flake update → push
\`/rollback\`   Revert to previous generation

📊 *Monitoring*
\`/status\`     Quick system snapshot
\`/health\`     Full deployment health check
\`/log [n]\`    Last n journal lines _(default 50)_

🧹 *Maintenance*
\`/gc\`         Garbage‑collect the nix store
\`/reboot\`     Reboot the host _(20s grace period)_
\`/shutdown\`   Power off the host _(20s grace period)_
\`/cancel\`     Abort a pending reboot/shutdown

🖥 *Applications*
\`/firefox\`    Open Firefox on this host
\`/open <app>\` Launch any application

🔧 *Raw Access*
\`/git <cmd>\`  Run git in the infra repo
\`/nix <cmd>\`  Run an arbitrary nix command

📦 *GitLab*
\`/gitlab status\`     Project + latest pipeline
\`/gitlab pipelines\`  Recent pipelines
\`/gitlab trigger\`    Trigger a pipeline
\`/gitlab mr\`         List merge requests

ℹ️ \`/help\`     Show this menu
${sep}
🔒 Authorized chat only · replies may be split across messages"
      ;;

    status)
      send_msg "$chat" "📊 Gathering system info…"
      local kernel disk gen upt load mem
      kernel="$(uname -srm 2>/dev/null || echo 'unknown')"
      disk="$(df -h / --output=size,used,avail,pcent 2>/dev/null | tail -1 | awk '{print $2" total, "$3" used, "$4" free ("$5")"}')"
      gen="$(nixos-rebuild list-generations 2>/dev/null | tail -1 | awk '{$1=""; print $0}' | xargs || echo 'unknown')"
      upt="$(uptime 2>/dev/null | sed 's/.*up //; s/,.*//' || echo 'unknown')"
      load="$(uptime 2>/dev/null | awk -F'load average: ' '{print $2}' || echo 'unknown')"
      mem="$(free -h 2>/dev/null | awk '/^Mem:/{print $3" used / "$2" total"}' || echo 'unknown')"
      send_long "$chat" "🛰 *${HOST}* — System Status
${sep}
🧬 *Kernel:*    \`${kernel}\`
⏱ *Uptime:*    \`${upt}\`
📈 *Load avg:*  \`${load}\`
🧠 *Memory:*    \`${mem}\`
💾 *Disk (/):*  \`${disk}\`
🧊 *NixGen:*    \`${gen}\`
${sep}
Run \`/health\` for a full diagnostic."
      ;;

    health)
      send_msg "$chat" "🩺 Running health checks…"
      local out
      out="🩺 *${HOST}* — Health Report
${sep}"
      out+="\`\`\`"
      out+="$(run_cmd "cd ${REPO_DIR} && scripts/deployment-health.sh 2>&1" 60)"
      out+="\`\`\`"
      out+="
${sep}
✅ Check complete."
      send_long "$chat" "$out"
      ;;

    deploy|rebuild)
      send_msg "$chat" "🚀 Deploying *${HOST}*…"
      local out
      out="🚀 *${HOST}* — Deploy Output
${sep}"
      out+="\`\`\`"
      out+="$(run_cmd "cd ${REPO_DIR} && nixos-rebuild switch --flake .#${HOST} --show-trace 2>&1" 600)"
      out+="\`\`\`"
      out+="
${sep}
🏁 Deploy finished."
      send_long "$chat" "$out"
      ;;

    update)
      send_msg "$chat" "🔄 Updating flake inputs…"
      local out
      out="🔄 *${HOST}* — Flake Update
${sep}"
      out+="\`\`\`"
      out+="$(run_cmd "cd ${REPO_DIR} && git pull --ff-only origin main 2>&1 && nix flake update 2>&1 && git add flake.lock && git commit -m 'flake update: $(date -Iseconds)' 2>&1 && git push origin main 2>&1" 600)"
      out+="\`\`\`"
      out+="
${sep}
📦 Inputs refreshed & pushed."
      send_long "$chat" "$out"
      ;;

    rollback)
      send_msg "$chat" "⏪ Rolling back…"
      local out
      out="⏪ *${HOST}* — Rollback
${sep}"
      out+="\`\`\`"
      out+="$(run_cmd "cd ${REPO_DIR} && scripts/rollback.sh 2>&1" 120)"
      out+="\`\`\`"
      out+="
${sep}
↩️ Rollback complete."
      send_long "$chat" "$out"
      ;;

    gc)
      send_msg "$chat" "🧹 Running garbage collector…"
      local out
      out="🧹 *${HOST}* — GC Results
${sep}"
      out+="\`\`\`"
      out+="$(run_cmd "nix store gc 2>&1" 600)"
      out+="\`\`\`"
      out+="
${sep}
✨ Store cleaned."
      send_long "$chat" "$out"
      ;;

    reboot)
      send_msg "$chat" "♻️ *${HOST}* — Reboot
${sep}
Rebooting in 20 seconds… send \`/cancel\` to abort.
${sep}"
      _pending_action bash -c 'sleep 20 && systemctl reboot' &
      _PENDING_PID=$!
      ;;

    shutdown)
      send_msg "$chat" "⏻ *${HOST}* — Shutdown
${sep}
Shutting down in 20 seconds… send \`/cancel\` to abort.
${sep}"
      _pending_action bash -c 'sleep 20 && systemctl poweroff' &
      _PENDING_PID=$!
      ;;

    log)
      local lines="${args:-50}"
      local out
      out="📜 *${HOST}* — Last ${lines} journal lines
${sep}"
      out+="\`\`\`"
      out+="$(run_cmd "journalctl -n ${lines} --no-pager 2>&1" 30)"
      out+="\`\`\`"
      send_long "$chat" "$out"
      ;;

    git)
      if [[ -z "$args" ]]; then
        send_msg "$chat" "🔧 *Usage:* \`/git <command>\`
Runs a git command inside \`${REPO_DIR}\`
_Example:_ \`/git log --oneline -5\`"
        return
      fi
      local out
      out="🔧 *git ${args}*
${sep}"
      out+="\`\`\`"
      out+="$(run_cmd "cd ${REPO_DIR} && git ${args} 2>&1" 30)"
      out+="\`\`\`"
      send_long "$chat" "$out"
      ;;

    nix)
      if [[ -z "$args" ]]; then
        send_msg "$chat" "🔧 *Usage:* \`/nix <command>\`
_Example:_ \`/nix flake check\`"
        return
      fi
      local out
      out="🔧 *nix ${args}*
${sep}"
      out+="\`\`\`"
      out+="$(run_cmd "nix ${args} 2>&1" 300)"
      out+="\`\`\`"
      send_long "$chat" "$out"
      ;;

    firefox)
      send_msg "$chat" "🦊 Opening Firefox on *${HOST}*…"
      local uid
      uid="$(id -u "${DEFAULT_USER}" 2>/dev/null || echo '1000')"
      run_cmd "sudo -u ${DEFAULT_USER} bash -c 'DISPLAY=:0 WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/${uid} nohup firefox >/dev/null 2>&1 &'" 10
      send_msg "$chat" "✅ Firefox launched."
      ;;

    open)
      if [[ -z "$args" ]]; then
        send_msg "$chat" "🖥 *Usage:* \`/open <application>\`
_Launches any application as ${DEFAULT_USER}._
_Example:_ \`/open code\`"
        return
      fi
      local app="$args"
      send_msg "$chat" "🖥 Opening *${app}* on *${HOST}*…"
      local uid
      uid="$(id -u "${DEFAULT_USER}" 2>/dev/null || echo '1000')"
      run_cmd "sudo -u ${DEFAULT_USER} bash -c 'DISPLAY=:0 WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/${uid} nohup \"${app}\" >/dev/null 2>&1 &'" 10
      send_msg "$chat" "✅ ${app} launched."
      ;;

    gitlab)
      if [[ -z "$GITLAB_TOKEN" ]]; then
        send_msg "$chat" "❌ GitLab token not configured."
        return
      fi
      local subcmd="${args%% *}"
      local subargs="${args#* }"
      case "$subcmd" in
        status)
          send_msg "$chat" "📦 Fetching GitLab project info…"
          local proj out
          proj="$(gitlab_api "/projects/${GITLAB_PROJECT}")"
          local name default_branch
          name="$(echo "$proj" | jq -r '.name // "unknown"')"
          default_branch="$(echo "$proj" | jq -r '.default_branch // "unknown"')"
          out="📦 *GitLab — ${name}*
${sep}
📋 *Default branch:* \`${default_branch}\`
🔗 *URL:* ${GITLAB_URL}
${sep}
*Latest pipeline:*
\`\`\`"
          local pipe
          pipe="$(gitlab_api "/projects/${GITLAB_PROJECT}/pipelines?per_page=1")"
          out+="$(echo "$pipe" | jq -r '.[0] | "  #\(.id) [\(.status)] \(.ref) \(.commit.title // "")"' 2>/dev/null || echo '  no pipelines found')"
          out+="\`\`\`"
          send_long "$chat" "$out"
          ;;
        pipelines)
          send_msg "$chat" "📦 Fetching recent pipelines…"
          local pipes out
          pipes="$(gitlab_api "/projects/${GITLAB_PROJECT}/pipelines?per_page=10")"
          out="📦 *Recent Pipelines*
${sep}
\`\`\`"
          out+="$(echo "$pipes" | jq -r '.[] | "#\(.id)  \(.status | ascii_upcase | .[0:12])  \(.ref)  \(.created_at | split("T")[0])"' 2>/dev/null || echo '  no pipelines found')"
          out+="\`\`\`"
          send_long "$chat" "$out"
          ;;
        trigger)
          send_msg "$chat" "🚀 Triggering pipeline on *main*…"
          local result
          result="$(gitlab_api "/projects/${GITLAB_PROJECT}/pipeline" "POST" '{"ref":"main"}' | jq -r '.id // empty' 2>/dev/null)"
          if [[ -n "$result" ]]; then
            send_msg "$chat" "✅ Pipeline *#${result}* triggered."
          else
            send_msg "$chat" "❌ Failed to trigger pipeline."
          fi
          ;;
        mr)
          send_msg "$chat" "📋 Fetching merge requests…"
          local mrs out
          mrs="$(gitlab_api "/projects/${GITLAB_PROJECT}/merge_requests?state=opened&per_page=10")"
          out="📋 *Open Merge Requests*
${sep}
\`\`\`"
          out+="$(echo "$mrs" | jq -r '.[] | "  !\(.iid)  \(.title[0:50])  ← \(.source_branch)"' 2>/dev/null || echo '  no open MRs')"
          out+="\`\`\`"
          send_long "$chat" "$out"
          ;;
        *)
          send_msg "$chat" "📦 *GitLab Usage:*
\`/gitlab status\`     Project + latest pipeline
\`/gitlab pipelines\`  Recent pipelines
\`/gitlab trigger\`    Trigger a pipeline
\`/gitlab mr\`         List merge requests"
          ;;
      esac
      ;;

    cancel)
      if [[ -n "$_PENDING_PID" ]] && kill -0 "$_PENDING_PID" 2>/dev/null; then
        kill "$_PENDING_PID" 2>/dev/null || true
        _PENDING_PID=""
        send_msg "$chat" "🛑 Cancelled."
      else
        send_msg "$chat" "ℹ️ No pending reboot/shutdown to cancel."
      fi
      ;;

    *)
      send_msg "$chat" "❓ *Unknown command:* \`/${cmd}\`
Send \`/help\` to see what's available."
      ;;
  esac
}

log "Bot starting — host=${HOST} chat=${CHAT_ID}"

register_commands() {
  curl -fsSL --max-time 10 -X POST "${API}/setMyCommands" \
    -H "Content-Type: application/json" \
    -d '{"commands":[
      {"command":"deploy","description":"🚀 nixos-rebuild switch"},
      {"command":"status","description":"📊 Quick system snapshot"},
      {"command":"health","description":"🩺 Full deployment health check"},
      {"command":"update","description":"🔄 git pull + flake update + push"},
      {"command":"rollback","description":"⏪ Revert to previous generation"},
      {"command":"gc","description":"🧹 Nix store garbage collect"},
      {"command":"reboot","description":"♻️ Reboot the system"},
      {"command":"shutdown","description":"⏻ Power off the system"},
      {"command":"log","description":"📜 Last N journal lines"},
      {"command":"firefox","description":"🦊 Open Firefox"},
      {"command":"open","description":"🖥 Launch any application"},
      {"command":"git","description":"🔧 Run a git command"},
      {"command":"nix","description":"🔧 Run a nix command"},
      {"command":"gitlab","description":"📦 GitLab pipelines & MRs"},
      {"command":"help","description":"ℹ️ Show this menu"}
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

    if [[ "$text" =~ ^/([a-zA-Z]+)([[:space:]]+(.*))?$ ]]; then
      cmd="${BASH_REMATCH[1]}"
      args="${BASH_REMATCH[3]:-}"
      handle_command "$chat" "$cmd" "$args"
    fi
  done < <(echo "$updates" | jq -c '.result[]' 2>/dev/null)
done
