#!/usr/bin/env bash
# commands/desktop_power.sh — /lock, /logout, /suspend, /hibernate, /monitor-off, /monitor-on
##############################################################################

_cmd_lock() {
  local chat="$1" args="$2"
  loginctl lock-session 2>/dev/null
  send_msg "$chat" "🔒 Screen locked."
}

_cmd_logout() {
  local chat="$1" args="$2"
  send_msg "$chat" "👋 Logging out…"
  gnome-session-quit --no-prompt 2>/dev/null || loginctl terminate-user "${DEFAULT_USER}" 2>/dev/null
}

_cmd_suspend() {
  local chat="$1" args="$2"
  send_msg "$chat" "💤 Suspending…"
  systemctl suspend 2>/dev/null
}

_cmd_hibernate() {
  local chat="$1" args="$2"
  send_msg "$chat" "ibernating…"
  systemctl hibernate 2>/dev/null
}

_cmd_monitor_off() {
  local chat="$1" args="$2"
  # Try GNOME DPMS via xset (works through XWayland)
  local -a env_args
  if session_env_args "$chat" env_args; then
    sudo -u "${DEFAULT_USER}" env "${env_args[@]}" \
      xset dpms force off 2>/dev/null
    send_msg "$chat" "🖥 Display off."
  else
    send_msg "$chat" "❌ No session available."
  fi
}

_cmd_monitor_on() {
  local chat="$1" args="$2"
  local -a env_args
  if session_env_args "$chat" env_args; then
    sudo -u "${DEFAULT_USER}" env "${env_args[@]}" \
      xset dpms force on 2>/dev/null
    send_msg "$chat" "🖥 Display on."
  else
    send_msg "$chat" "❌ No session available."
  fi
}

register_command "lock" "_cmd_lock" "🔒 Lock screen"
register_command "logout" "_cmd_logout" "👋 Log out"
register_command "suspend" "_cmd_suspend" "💤 Suspend"
register_command "hibernate" "_cmd_hibernate" "❄ Hibernate"
register_command "monitor-off" "_cmd_monitor_off" "🖥 Turn displays off"
register_command "monitor-on" "_cmd_monitor_on" "🖥 Wake displays"
