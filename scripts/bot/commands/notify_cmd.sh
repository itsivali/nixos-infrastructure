# commands/notify_cmd.sh — /notify <msg> — desktop notification
##############################################################################

_cmd_notify_cmd() {
  local chat="$1" args="$2"

  if [[ -z "$args" ]]; then
    send_msg "$chat" "🔔 *Usage:* \`/notify <message>\`
_Displays a desktop notification._
_Example:_ \`/notify Build complete!\`"
    return
  fi

  desktop::require_graphical "$chat" || return

  sudo -u "${DEFAULT_USER}" \
    XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
    notify-send "Notification from ${HOST}" "$args" 2>/dev/null

  send_msg "$chat" "🔔 Notification sent."
}

register_command "notify" "_cmd_notify_cmd" "🔔 Desktop notification"
