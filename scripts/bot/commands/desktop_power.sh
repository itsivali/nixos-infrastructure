# commands/desktop_power.sh — /lock, /logout, /suspend, /hibernate, /monitoroff, /monitoron
# Uses loginctl / hyprctl for Hyprland desktop control.
##############################################################################

_cmd_lock() {
  local chat="$1" args="$2"
  loginctl lock-sessions 2>/dev/null
  send_msg "$chat" "Screen locked."
}

_cmd_logout() {
  local chat="$1" args="$2"
  send_msg "$chat" "Logging out..."
  desktop::hyprctl_call dispatch exit >/dev/null 2>&1
}

_cmd_suspend() {
  local chat="$1" args="$2"
  send_msg "$chat" "Suspending..."
  systemctl suspend 2>/dev/null
}

_cmd_hibernate() {
  local chat="$1" args="$2"
  send_msg "$chat" "Hibernating..."
  systemctl hibernate 2>/dev/null
}

_cmd_monitor_off() {
  local chat="$1" args="$2"
  desktop::hyprctl_call dispatch dpms off >/dev/null 2>&1
  loginctl lock-sessions 2>/dev/null
  send_msg "$chat" "Display off."
}

_cmd_monitor_on() {
  local chat="$1" args="$2"
  desktop::hyprctl_call dispatch dpms on >/dev/null 2>&1
  send_msg "$chat" "Display on."
}

register_command "lock" "_cmd_lock" "Lock screen"
register_command "logout" "_cmd_logout" "Log out"
register_command "suspend" "_cmd_suspend" "Suspend"
register_command "hibernate" "_cmd_hibernate" "Hibernate"
register_command "monitoroff" "_cmd_monitor_off" "Turn displays off"
register_command "monitoron" "_cmd_monitor_on" "Wake displays"
