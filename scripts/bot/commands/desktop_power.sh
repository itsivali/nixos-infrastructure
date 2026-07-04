# commands/desktop_power.sh — /lock, /logout, /suspend, /hibernate, /monitoroff, /monitoron
# Uses GNOME Shell D-Bus API for display power management (Wayland-native).
##############################################################################

_cmd_lock() {
  local chat="$1" args="$2"
  loginctl lock-sessions 2>/dev/null
  send_msg "$chat" "🔒 Screen locked."
}

_cmd_logout() {
  local chat="$1" args="$2"
  send_msg "$chat" "👋 Logging out…"
  # Try GNOME session quit first, fall back to loginctl
  desktop::require_graphical "$chat" 2>/dev/null || {
    loginctl terminate-user "${DEFAULT_USER}" 2>/dev/null
    return
  }
  sudo -u "${DEFAULT_USER}" \
    XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
    gnome-session-quit --no-prompt 2>/dev/null || \
    loginctl terminate-user "${DEFAULT_USER}" 2>/dev/null
}

_cmd_suspend() {
  local chat="$1" args="$2"
  send_msg "$chat" "💤 Suspending…"
  systemctl suspend 2>/dev/null
}

_cmd_hibernate() {
  local chat="$1" args="$2"
  send_msg "$chat" "❄️ Hibernating…"
  systemctl hibernate 2>/dev/null
}

_cmd_monitor_off() {
  local chat="$1" args="$2"
  # Use GNOME Shell ScreenSaver D-Bus (Wayland-native)
  desktop::require_graphical "$chat" || return
  desktop::dbus_call \
    org.gnome.ScreenSaver /org/gnome/ScreenSaver \
    org.gnome.ScreenSaver.SetActive true
  send_msg "$chat" "🖥 Display off."
}

_cmd_monitor_on() {
  local chat="$1" args="$2"
  # Use GNOME Shell ScreenSaver D-Bus (Wayland-native)
  desktop::require_graphical "$chat" || return
  desktop::dbus_call \
    org.gnome.ScreenSaver /org/gnome/ScreenSaver \
    org.gnome.ScreenSaver.SetActive false
  send_msg "$chat" "🖥 Display on."
}

register_command "lock" "_cmd_lock" "🔒 Lock screen"
register_command "logout" "_cmd_logout" "👋 Log out"
register_command "suspend" "_cmd_suspend" "💤 Suspend"
register_command "hibernate" "_cmd_hibernate" "❄ Hibernate"
register_command "monitoroff" "_cmd_monitor_off" "🖥 Turn displays off"
register_command "monitoron" "_cmd_monitor_on" "🖥 Wake displays"
