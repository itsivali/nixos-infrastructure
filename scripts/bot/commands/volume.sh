# commands/volume.sh — /volume [N], /mute, /unmute — audio control via WirePlumber
##############################################################################

_cmd_volume() {
  local chat="$1" args="$2"

  desktop::require_graphical "$chat" || return

  local wpctl
  wpctl="$(desktop::resolve_binary wpctl)" || true
  if [[ -z "$wpctl" ]]; then
    send_msg "$chat" "❌ wpctl (WirePlumber) not found on ${HOST}."
    return
  fi

  local subcmd="${args%% *}"
  local value="${args#* }"

  _volume_get() {
    sudo -u "${DEFAULT_USER}" \
      XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
      DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
      "$wpctl" get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null
  }

  _volume_set() {
    sudo -u "${DEFAULT_USER}" \
      XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
      DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
      "$wpctl" set-volume @DEFAULT_AUDIO_SINK@ "$1" 2>/dev/null
  }

  _volume_mute() {
    sudo -u "${DEFAULT_USER}" \
      XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
      DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
      "$wpctl" set-mute @DEFAULT_AUDIO_SINK@ "$1" 2>/dev/null
  }

  case "$subcmd" in
    ""|info)
      local vol
      vol="$(_volume_get)" || true
      send_msg "$chat" "🔊 ${vol:-Could not read volume}"
      ;;
    mute)
      _volume_mute 1
      send_msg "$chat" "🔇 Muted"
      ;;
    unmute)
      _volume_mute 0
      send_msg "$chat" "🔊 Unmuted"
      ;;
    +*|-*)
      local delta="${subcmd}"
      local current
      current="$(_volume_get)" || true
      local pct
      pct="$(echo "$current" | awk '{printf "%d", $2 * 100}')"
      local new_pct=$(( pct + delta ))
      (( new_pct = new_pct > 150 ? 150 : new_pct < 0 ? 0 : new_pct ))
      local decimal
      decimal="$(awk "BEGIN{printf \"%.2f\", $new_pct / 100}")"
      _volume_set "$decimal"
      send_msg "$chat" "🔊 Volume set to ${new_pct}%"
      ;;
    [0-9]*)
      local pct="$value"
      pct="${pct%%%}"
      if [[ "$pct" =~ ^[0-9]+$ ]] && (( pct >= 0 && pct <= 150 )); then
        _volume_set "$(( pct / 100 )).$(( pct % 100 ))"
        send_msg "$chat" "🔊 Volume set to ${pct}%"
      else
        send_msg "$chat" "🔧 *Usage:* \`/volume <0-150>\`"
      fi
      ;;
    *)
      send_msg "$chat" "🔊 *Usage:*
\`/volume\` — Show volume
\`/volume 75\` — Set volume (0-150)
\`/volume +5\` — Increase by 5%
\`/volume -10\` — Decrease by 10%
\`/mute\` — Mute
\`/unmute\` — Unmute"
      ;;
  esac
}

_cmd_mute() {
  local chat="$1" args="$2"
  _cmd_volume "$chat" "mute"
}

_cmd_unmute() {
  local chat="$1" args="$2"
  _cmd_volume "$chat" "unmute"
}

register_command "volume" "_cmd_volume" "🔊 Volume control"
register_command "mute" "_cmd_mute" "🔇 Mute audio"
register_command "unmute" "_cmd_unmute" "🔊 Unmute audio"
