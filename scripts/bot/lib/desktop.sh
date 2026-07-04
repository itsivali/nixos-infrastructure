# lib/desktop.sh — Desktop session bridging, D-Bus/Portal abstraction layer
#
# Dependencies: lib/core.sh (log), lib/telegram.sh (send_msg)
# Provides:     desktop::ensure_session_env, desktop::ext_dbus_call,
#               desktop::dbus_call, desktop::session_type,
#               desktop::launch_app, desktop::launch_detached,
#               desktop::require_graphical, desktop::resolve_binary
##############################################################################

# ── Constants ──────────────────────────────────────────────────────────────
_DESKTOP_EXT_BUS="org.gnome.Shell.Extensions.DesktopControl"
_DESKTOP_EXT_PATH="/org/gnome/Shell/Extensions/DesktopControl"
_DESKTOP_EXT_IFACE="org.gnome.Shell.Extensions.DesktopControl"

# ── Session environment bridging ───────────────────────────────────────────

# Detect the active graphical session for DEFAULT_USER.
# Reads DBUS_SESSION_BUS_ADDRESS and XDG_RUNTIME_DIR from the gnome-shell
# process. This is more robust than loginctl env vars because it works across
# session restarts without requiring service restart.
# Usage: desktop::ensure_session_env || return 1
# On success, exports DBUS_SESSION_BUS_ADDRESS, XDG_RUNTIME_DIR,
# WAYLAND_DISPLAY, and DISPLAY into the current shell.
desktop::ensure_session_env() {
  local uid
  uid="$(id -u "${DEFAULT_USER}" 2>/dev/null || echo 1000)"

  # Use caller-provided XDG_RUNTIME_DIR if set, otherwise derive from uid
  if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
    XDG_RUNTIME_DIR="/run/user/${uid}"
  fi
  DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${XDG_RUNTIME_DIR}/bus}"
  WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
  DISPLAY="${DISPLAY:-:0}"

  if [[ ! -d "${XDG_RUNTIME_DIR}" || ! -S "${XDG_RUNTIME_DIR}/bus" ]]; then
    return 1
  fi

  export XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS WAYLAND_DISPLAY DISPLAY
  return 0
}

# ── Session type detection ─────────────────────────────────────────────────

# Return the active session type.
# Works with XDG_RUNTIME_DIR override for testing.
# Usage: desktop::session_type  # prints "wayland" or "x11"
desktop::session_type() {
  local uid
  uid="$(id -u "${DEFAULT_USER}" 2>/dev/null || echo 1000)"
  local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/${uid}}"

  if [[ -S "${runtime_dir}/wayland-0" ]]; then
    echo "wayland"
  elif [[ -n "${DISPLAY:-}" ]]; then
    echo "x11"
  else
    echo "unknown"
  fi
}

# ── Graphical session validation ───────────────────────────────────────────

# Validate that a graphical session exists for DEFAULT_USER.
# Sends error to chat on failure.
# Usage: desktop::require_graphical "$chat" || return
desktop::require_graphical() {
  local chat="$1"
  if ! desktop::ensure_session_env; then
    send_msg "$chat" "❌ No graphical session found for ${DEFAULT_USER} on ${HOST}."
    return 1
  fi
  return 0
}

# ── D-Bus calls ────────────────────────────────────────────────────────────

# Make a session D-Bus call as DEFAULT_USER with proper environment.
# Usage: desktop::dbus_call <dest> <path> <interface.method> [args...]
# Example: desktop::dbus_call org.gnome.ScreenSaver /org/gnome/ScreenSaver \
#           org.gnome.ScreenSaver.SetActive true
desktop::dbus_call() {
  local dest="$1" path="$2" method="$3"
  shift 3
  desktop::ensure_session_env 2>/dev/null || return 1
  sudo -u "${DEFAULT_USER}" \
    XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
    gdbus call --session --dest "$dest" --object-path "$path" \
    --method "$method" "$@" 2>/dev/null || true
}

# Call the DesktopControl GNOME Shell extension via D-Bus.
# Usage: desktop::ext_dbus_call <method> [args...]
# Returns the raw D-Bus response string.
desktop::ext_dbus_call() {
  local method="$1"
  shift 1
  desktop::dbus_call \
    "$_DESKTOP_EXT_BUS" \
    "$_DESKTOP_EXT_PATH" \
    "${_DESKTOP_EXT_IFACE}.${method}" \
    "$@"
}

# ── Application resolution ─────────────────────────────────────────────────

# Resolve a binary to its full store path.
# Usage: bin_path="$(desktop::resolve_binary "firefox")"
desktop::resolve_binary() {
  local bin="$1"

  # 1. Check system closure (NixOS system packages)
  local sys_path="/run/current-system/sw/bin/${bin}"
  if [[ -x "$sys_path" ]]; then
    echo "$sys_path"
    return 0
  fi

  # 2. Check current process PATH (includes service path attribute)
  local cmd_path
  cmd_path="$(command -v "$bin" 2>/dev/null)" || true
  if [[ -n "$cmd_path" ]]; then
    echo "$cmd_path"
    return 0
  fi

  # 3. Fallback: check user's PATH via sudo
  local uid
  uid="$(id -u "${DEFAULT_USER}" 2>/dev/null || echo 1000)"
  sudo -u "${DEFAULT_USER}" env XDG_RUNTIME_DIR="/run/user/${uid}" \
    command -v "$bin" 2>/dev/null
}

# Validate that a binary exists for DEFAULT_USER.
# Usage: desktop::require_binary "$chat" "firefox" || return
desktop::require_binary() {
  local chat="$1" bin="$2"
  if ! desktop::resolve_binary "$bin" >/dev/null 2>&1; then
    send_msg "$chat" "❌ \`${bin}\` not found in ${DEFAULT_USER}'s PATH on ${HOST}."
    return 1
  fi
  return 0
}

# ── Application launching ──────────────────────────────────────────────────

# Launch an application via systemd-run --user --scope for proper session
# integration. Falls back to nohup if systemd-run is unavailable.
# Usage: desktop::launch_app "$chat" "firefox --new-window https://..."
desktop::launch_app() {
  local chat="$1" cmdline="$2"
  local bin="${cmdline%% *}"

  local resolved_bin
  resolved_bin="$(desktop::resolve_binary "$bin")" || true
  if [[ -z "$resolved_bin" ]]; then
    send_msg "$chat" "❌ \`${bin}\` not found on ${HOST}."
    return 1
  fi

  desktop::ensure_session_env || {
    send_msg "$chat" "❌ No graphical session found for ${DEFAULT_USER} on ${HOST}."
    return 1
  }

  local resolved_cmdline="${resolved_bin}${cmdline#"$bin"}"
  local -a args_array
  read -ra args_array <<< "$resolved_cmdline"

  # Try systemd-run --user --scope first (best session integration)
  if sudo -u "${DEFAULT_USER}" \
    XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
    WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
    DISPLAY="$DISPLAY" \
    systemd-run --user --scope "${args_array[@]}" >/dev/null 2>&1; then
    send_msg "$chat" "✅ \`${bin}\` launching on *${HOST}*."
    return 0
  fi

  # Fallback to nohup
  sudo -u "${DEFAULT_USER}" \
    XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
    WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
    DISPLAY="$DISPLAY" \
    bash -c 'nohup "$@" >/dev/null 2>&1 & disown' _ "${args_array[@]}"

  send_msg "$chat" "✅ \`${bin}\` launching on *${HOST}* (nohup)."
}
