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
    "${_CMD_HANDLER[$cmd]}" "$chat" "$args"
  else
    send_msg "$chat" "❓ *Unknown command:* \`/${cmd}\`
Send \`/help\` to see what's available."
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
\`/logout\`       Log out of GNOME
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
# Usage: register_commands_api
register_commands_api() {
  local json='{"commands":['
  local first=true
  for name in "${_CMD_ORDER[@]}"; do
    # Skip commands without a description
    [[ -z "${_CMD_DESC[$name]:-}" ]] && continue
    if [[ "$first" == true ]]; then
      first=false
    else
      json+=','
    fi
    json+="{\"command\":\"${name}\",\"description\":\"${_CMD_DESC[$name]}\"}"
  done
  json+=']}'

  curl -fsSL --max-time 10 -X POST "${API}/setMyCommands" \
    -H "Content-Type: application/json" \
    -d "$json" > /dev/null 2>&1 || true
}
