#!/usr/bin/env bash
# lib/desktop.sh — Desktop session detection, validation, and application launching
#
# Dependencies: lib/telegram.sh, lib/core.sh (log)
# Provides:     detect_session, require_session, validate_binary, launch_app,
#               gnome_dbus, session_env_args
##############################################################################

# Detect the running graphical session's environment variables for a user.
# Populates DISPLAY, WAYLAND_DISPLAY, XDG_RUNTIME_DIR, DBUS_SESSION_BUS_ADDRESS.
# Usage: eval "$(detect_session "$uid")"
detect_session() {
  local uid="$1"
  local runtime_dir="/run/user/${uid}"

  if [[ ! -d "$runtime_dir" ]]; then
    return 1
  fi

  echo "XDG_RUNTIME_DIR=${runtime_dir}"

  local wl
  wl="$(find "$runtime_dir" -maxdepth 1 -name 'wayland-*' ! -name '*.lock' 2>/dev/null | head -n1)"
  [[ -n "$wl" ]] && echo "WAYLAND_DISPLAY=$(basename "$wl")"

  local x11
  x11="$(find /tmp/.X11-unix -maxdepth 1 -name 'X*' 2>/dev/null | head -n1)"
  [[ -n "$x11" ]] && echo "DISPLAY=:$(basename "$x11" | sed 's/^X//')"

  [[ -S "${runtime_dir}/bus" ]] && echo "DBUS_SESSION_BUS_ADDRESS=unix:path=${runtime_dir}/bus"

  return 0
}

# Validate that a graphical session exists for DEFAULT_USER.
# Returns array of env vars. Sends error to chat if no session.
# Usage: env_args=(); session_env_args "$chat" env_args || return
session_env_args() {
  local chat="$1"
  local -n _env_ref="$2"
  local uid
  uid="$(id -u "${DEFAULT_USER}" 2>/dev/null || echo '1000')"

  local env_lines
  if ! env_lines="$(detect_session "$uid")"; then
    send_msg "$chat" "❌ No graphical session found for ${DEFAULT_USER} on ${HOST}."
    return 1
  fi

  _env_ref=()
  while IFS= read -r line; do
    _env_ref+=("$line")
  done <<< "$env_lines"

  return 0
}

# Validate that a binary exists in DEFAULT_USER's PATH.
# Usage: validate_binary "$chat" "firefox" || return
validate_binary() {
  local chat="$1" bin="$2"
  if ! sudo -u "${DEFAULT_USER}" bash -c 'command -v -- "$1"' _ "$bin" >/dev/null 2>&1; then
    send_msg "$chat" "❌ \`${bin}\` not found in ${DEFAULT_USER}'s PATH on ${HOST}."
    return 1
  fi
  return 0
}

# Launch an application as DEFAULT_USER with proper session environment.
# Splits command line into argv correctly so "/open code ~/project" works.
# Usage: launch_app "$chat" "firefox --new-window https://example.com"
launch_app() {
  local chat="$1" cmdline="$2"
  local bin="${cmdline%% *}"

  validate_binary "$chat" "$bin" || return 1

  local -a env_args
  session_env_args "$chat" env_args || return 1

  local -a args_array
  read -ra args_array <<< "$cmdline"

  sudo -u "${DEFAULT_USER}" env "${env_args[@]}" \
    bash -c 'nohup "$@" >/dev/null 2>&1 & disown' _ "${args_array[@]}"

  send_msg "$chat" "✅ \`${bin}\` launching on *${HOST}*."
}

# Launch an application via systemd-run --user --scope for better session integration.
# Falls back to launch_app if systemd-run fails.
# Usage: launch_systemd "$chat" "firefox"
launch_systemd() {
  local chat="$1" cmdline="$2"
  local bin="${cmdline%% *}"

  validate_binary "$chat" "$bin" || return 1

  local -a env_args
  session_env_args "$chat" env_args || return 1

  local -a args_array
  read -ra args_array <<< "$cmdline"

  # Try systemd-run first
  if sudo -u "${DEFAULT_USER}" env "${env_args[@]}" \
    systemd-run --user --scope "${args_array[@]}" >/dev/null 2>&1; then
    send_msg "$chat" "✅ \`${bin}\` launching on *${HOST}* (systemd)."
    return 0
  fi

  # Fallback to nohup
  launch_app "$chat" "$cmdline"
}

# Call a GNOME Shell DBus method.
# Usage: gnome_dbus "org.gnome.ScreenSaver" "/org/gnome/ScreenSaver" "Lock"
gnome_dbus() {
  local dest="$1" path="$2" method="$3"
  shift 3
  gdbus call --session --dest "$dest" --object-path "$path" \
    --method "$dest.$method" "$@" 2>/dev/null || true
}
