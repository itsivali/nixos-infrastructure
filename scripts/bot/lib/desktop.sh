# lib/desktop.sh — Desktop session bridging, Hyprland hyprctl abstraction layer
#
# Dependencies: lib/core.sh (log), lib/telegram.sh (send_msg)
# Provides:     desktop::ensure_session_env, desktop::hyprctl_call,
#               desktop::session_type, desktop::launch_app,
#               desktop::launch_detached, desktop::require_graphical,
#               desktop::resolve_binary, desktop::hyprctl_json
##############################################################################

# ── Session environment bridging ───────────────────────────────────────────

# Detect the active graphical session for DEFAULT_USER.
# Reads DBUS_SESSION_BUS_ADDRESS and XDG_RUNTIME_DIR from the user session.
desktop::ensure_session_env() {
  local uid
  uid="$(id -u "${DEFAULT_USER}" 2>/dev/null || echo 1000)"

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
desktop::require_graphical() {
  local chat="$1"
  if ! desktop::ensure_session_env; then
    send_msg "$chat" "No graphical session found for ${DEFAULT_USER} on ${HOST}."
    return 1
  fi
  return 0
}

# ── Hyprland hyprctl calls ────────────────────────────────────────────────
# Run hyprctl as DEFAULT_USER.
# Usage: desktop::hyprctl_call <args...>
desktop::hyprctl_call() {
  desktop::ensure_session_env 2>/dev/null || return 1
  sudo -u "${DEFAULT_USER}" \
    XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
    hyprctl "$@" 2>/dev/null || true
}

# Call hyprctl with JSON output, parse with jq.
# Usage: desktop::hyprctl_json <args...>
desktop::hyprctl_json() {
  desktop::hyprctl_call -j "$@" 2>/dev/null || true
}

# ── GNOME Shell D-Bus calls (compat, deprecated) ─────────────────────────
desktop::gnome_call() {
  local method="$1"
  shift
  desktop::ensure_session_env 2>/dev/null || return 1
  sudo -u "${DEFAULT_USER}" \
    XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
    gdbus call --session \
    --dest "org.gnome.Shell" \
    --object-path "/org/gnome/Shell" \
    --method "$method" "$@" 2>/dev/null || true
}

# ── D-Bus calls ────────────────────────────────────────────────────────────
# Make a session D-Bus call as DEFAULT_USER.
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

# ── Application resolution ─────────────────────────────────────────────────
desktop::resolve_binary() {
  local bin="$1"

  local sys_path="/run/current-system/sw/bin/${bin}"
  if [[ -x "$sys_path" ]]; then
    echo "$sys_path"
    return 0
  fi

  local cmd_path
  cmd_path="$(command -v "$bin" 2>/dev/null)" || true
  if [[ -n "$cmd_path" ]]; then
    echo "$cmd_path"
    return 0
  fi

  local uid
  uid="$(id -u "${DEFAULT_USER}" 2>/dev/null || echo 1000)"
  sudo -u "${DEFAULT_USER}" env XDG_RUNTIME_DIR="/run/user/${uid}" \
    command -v "$bin" 2>/dev/null
}

desktop::require_binary() {
  local chat="$1" bin="$2"
  if ! desktop::resolve_binary "$bin" >/dev/null 2>&1; then
    send_msg "$chat" "\`${bin}\` not found in ${DEFAULT_USER}'s PATH on ${HOST}."
    return 1
  fi
  return 0
}

# ── Application launching ──────────────────────────────────────────────────
desktop::launch_app() {
  local chat="$1" cmdline="$2"
  local bin="${cmdline%% *}"

  local resolved_bin
  resolved_bin="$(desktop::resolve_binary "$bin")" || true
  if [[ -z "$resolved_bin" ]]; then
    send_msg "$chat" "\`${bin}\` not found on ${HOST}."
    return 1
  fi

  desktop::ensure_session_env || {
    send_msg "$chat" "No graphical session found for ${DEFAULT_USER} on ${HOST}."
    return 1
  }

  local resolved_cmdline="${resolved_bin}${cmdline#"$bin"}"
  local -a args_array
  read -ra args_array <<< "$resolved_cmdline"

  if sudo -u "${DEFAULT_USER}" \
    XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
    WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
    DISPLAY="$DISPLAY" \
    systemd-run --user --scope "${args_array[@]}" >/dev/null 2>&1; then
    send_msg "$chat" "\`${bin}\` launching on *${HOST}*."
    return 0
  fi

  sudo -u "${DEFAULT_USER}" \
    XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
    WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
    DISPLAY="$DISPLAY" \
    bash -c 'nohup "$@" >/dev/null 2>&1 & disown' _ "${args_array[@]}"

  send_msg "$chat" "\`${bin}\` launching on *${HOST}* (nohup)."
}
