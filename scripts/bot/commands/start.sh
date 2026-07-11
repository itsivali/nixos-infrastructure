#!/usr/bin/env bash
# commands/start.sh — /start — Greet and show persistent keyboard menu
##############################################################################

_cmd_start() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"
  local uptime_str
  uptime_str="$(uptime 2>/dev/null | sed 's/.*up //; s/,.*//' || echo "unknown")"

  local welcome="🛰 *${HOST}* — Control Plane
${sep}
_NixOS GitOps bot · Desktop control · Monitoring_
_System up_ \`${uptime_str}\` · _Gen_ \`$(nix_current_generation 2>/dev/null || echo "?")\`
${sep}

*Quick Actions:*
  \`/status\`    System snapshot
  \`/deploy\`    Apply NixOS config
  \`/open\`      Launch any application
  \`/screenshot\` Capture desktop

${sep}
_Tap a button below or type a command._"

  send_keyboard "$chat" "$welcome" \
    "/status" "/health" "/open" "/help" \
    "/deploy" "/rollback" "/screenshot" "/menu"
}

register_command "start" "_cmd_start" "ℹ️ Show this menu"
