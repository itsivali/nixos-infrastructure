#!/usr/bin/env bash
# lib/registry.sh — Command registry and dispatcher
#
# Dependencies: lib/telegram.sh (for unknown command error)
# Provides:     register_command, dispatch, generate_menu, generate_telegram_commands
##############################################################################

# Command registry: name → handler function
declare -A _CMD_HANDLER
# Command registry: name → short description (for Telegram menu)
declare -A _CMD_DESC
# Command registry: name → full help text
declare -A _CMD_HELP
# Ordered list of registered command names (for consistent output)
_CMD_ORDER=()

# Register a command handler.
# Usage: register_command "status" "_cmd_status" "📊 System snapshot" "📊 *Usage:* ..."
register_command() {
  local name="$1" handler="$2" desc="$3" help="${4:-}"
  _CMD_HANDLER["$name"]="$handler"
  _CMD_DESC["$name"]="$desc"
  _CMD_HELP["$name"]="$help"
  _CMD_ORDER+=("$name")
}

# Dispatch a command to its handler.
# Usage: dispatch "status" "$chat_id" "$args"
dispatch() {
  local cmd="$1" chat="$2" args="$3"

  if [[ -v "_CMD_HANDLER[$cmd]" ]]; then
    # Check permissions
    local required_role=$(get_command_role "$cmd")
    if ! check_permission "$chat" "$required_role"; then
      local user_role=$(get_user_role "$chat")
      send_msg "$chat" "🔒 *Access Denied*

Command: \`/${cmd}\`
Required role: *${required_role}*
Your role: *${user_role}*

Contact the system owner to request access."
      return
    fi
    
    "${_CMD_HANDLER[$cmd]}" "$chat" "$args"
  else
    send_msg "$chat" "❓ *Unknown command:* \`/${cmd}\`
Send \`/help\` to see what's available."
  fi
}

# ── Callback query registry (for inline keyboard button presses) ──────────────
declare -A _CALLBACK_HANDLER

# Register a callback query handler.
# Usage: register_callback "deploy_confirm" "_cmd_deploy_callback"
register_callback() {
  local name="$1" handler="$2"
  _CALLBACK_HANDLER["$name"]="$handler"
}

# Dispatch a callback query to its handler.
# Usage: dispatch_callback "$callback_id" "$chat" "$data"
dispatch_callback() {
  local cb_id="$1" chat="$2" data="$3"
  if [[ -v "_CALLBACK_HANDLER[$data]" ]]; then
    "${_CALLBACK_HANDLER[$data]}" "$chat" "$cb_id" "$data"
  else
    log "Unknown callback: ${data}"
    answer_callback "$cb_id" "Unknown action"
  fi
}

# Generate the full help menu from registered commands.
# Usage: send_msg "$chat" "$(generate_menu)"
generate_menu() {
  local sep="━━━━━━━━━━━━━━━━━━━━━━"
  local menu="🛰 *${HOST}* — Control Plane
${sep}
_NixOS GitOps bot · long-poll session active_
${sep}

🚀 *Deployment*
\`/deploy\`       Apply config — \`nixos-rebuild switch\`
\`/update\`       Pull → flake update → push
\`/rollback\`     Revert to previous generation

📊 *Monitoring*
\`/status\`       System snapshot (CPU, memory, disk, temp…)
\`/health\`       Full deployment health check
\`/log [n] [unit]\` Last n journal lines _(default 50)_
\`/processes\`    List running GUI processes

🧹 *Maintenance*
\`/gc\`           Garbage‑collect the nix store
\`/reboot\`       Reboot the host _(20s grace period)_
\`/shutdown\`     Power off the host _(20s grace period)_
\`/cancel\`       Abort a pending reboot/shutdown

🖥 *Applications*
\`/open <app>\`   Launch any application, URL, or folder
\`/firefox\`      Open Firefox
\`/apps\`         List discovered applications
\`/run <cmd>\`    Execute a shell command

🎛 *Desktop*
\`/screenshot\`   Capture desktop screenshot
\`/clipboard\`    Read/set clipboard
\`/volume\`       Volume info / set / mute / unmute
\`/brightness\`   Brightness info / set
\`/notify <msg>\` Send a desktop notification
\`/windows\`      List open windows
\`/focus <app>\`  Focus a window by title
\`/close <app>\`  Close a window by title
\`/workspace\`    Switch workspaces (next/prev/N)
\`/lock\`         Lock screen
\`/logout\`       Log out of desktop
\`/suspend\`      Suspend to RAM
\`/hibernate\`    Hibernate to disk
\`/monitor-off\`  Turn displays off
\`/monitor-on\`   Wake displays

🔧 *Raw Access*
\`/git <cmd>\`    Run git in the infra repo
\`/nix <cmd>\`    Run an arbitrary nix command

📦 *GitLab*
\`/gitlab status\`     Project + latest pipeline
\`/gitlab pipelines\`  Recent pipelines
\`/gitlab trigger\`    Trigger a pipeline
\`/gitlab mr\`         List merge requests

ℹ️ \`/help\`  \`/menu\`  Show this menu
${sep}
🔒 Authorized chat only · replies may be split across messages"

  echo "$menu"
}

# Generate the Telegram Bot API setMyCommands JSON from registered commands.
# Registers all commands that have a short description (3rd argument).
# This populates the "/" menu button next to the chat input.
# Usage: register_commands_api
register_commands_api() {
  # Build JSON array of commands
  local cmd_json=""
  local count=0
  for name in "${_CMD_ORDER[@]}"; do
    # Skip commands without a description
    [[ -z "${_CMD_DESC[$name]:-}" ]] && continue
    local desc="${_CMD_DESC[$name]}"
    # Escape any double quotes or backslashes in description for safe JSON
    desc="${desc//\\/\\\\}"
    desc="${desc//\"/\\\"}"
    if [[ -n "$cmd_json" ]]; then
      cmd_json+=','
    fi
    cmd_json+="{\"command\":\"${name}\",\"description\":\"${desc}\"}"
    (( count++ ))
  done

  # Wrap in the full API payload with explicit scope
  local json="{\"commands\":[${cmd_json}],\"scope\":{\"type\":\"default\"}}"

  log "register_commands_api: registering ${count} commands"

  # Call the Telegram API
  local resp
  resp="$(curl -sS --max-time 10 -X POST "${API}/setMyCommands" \
    -H "Content-Type: application/json" \
    -d "$json" 2>&1)" || true

  if [[ "$resp" == *'"ok":true'* ]]; then
    log "register_commands_api: success — ${count} commands registered for / menu"
  else
    log "register_commands_api: FAILED — response: ${resp}"
    # Retry once after a short delay in case of transient failure
    sleep 2
    resp="$(curl -sS --max-time 10 -X POST "${API}/setMyCommands" \
      -H "Content-Type: application/json" \
      -d "$json" 2>&1)" || true
    if [[ "$resp" == *'"ok":true'* ]]; then
      log "register_commands_api: retry success — ${count} commands registered"
    else
      log "register_commands_api: retry FAILED — response: ${resp}"
    fi
  fi
}
