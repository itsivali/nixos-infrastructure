#!/usr/bin/env bash
# commands/notify_cmd.sh — /notify <msg> — desktop notification
##############################################################################

_cmd_notify_cmd() {
  local chat="$1" args="$2"

  if [[ -z "$args" ]]; then
    send_msg "$chat" "🔔 *Usage:* \`/notify <message>\`
_Displays a GNOME desktop notification._
_Example:_ \`/notify Build complete!\`"
    return
  fi

  local -a env_args
  session_env_args "$chat" env_args || return

  sudo -u "${DEFAULT_USER}" env "${env_args[@]}" \
    notify-send "Notification from ${HOST}" "$args" 2>/dev/null

  send_msg "$chat" "🔔 Notification sent."
}

register_command "notify" "_cmd_notify_cmd" "🔔 Desktop notification"
