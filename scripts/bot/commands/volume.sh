#!/usr/bin/env bash
# commands/volume.sh — /volume [N], /mute, /unmute — audio control via WirePlumber
##############################################################################

_cmd_volume() {
  local chat="$1" args="$2"
  local -a env_args
  session_env_args "$chat" env_args || return

  local wpctl
  wpctl="$(resolve_binary wpctl)" || true
  if [[ -z "$wpctl" ]]; then
    send_msg "$chat" "❌ wpctl (WirePlumber) not found on ${HOST}."
    return
  fi

  local subcmd="${args%% *}"
  local value="${args#* }"

  case "$subcmd" in
    ""|info)
      local vol
      vol="$(sudo -u "${DEFAULT_USER}" env "${env_args[@]}" \
        "$wpctl" get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)" || true
      send_msg "$chat" "🔊 ${vol:-Could not read volume}"
      ;;
    mute|0)
      sudo -u "${DEFAULT_USER}" env "${env_args[@]}" \
        "$wpctl" set-mute @DEFAULT_AUDIO_SINK@ 1 2>/dev/null
      send_msg "$chat" "🔇 Muted"
      ;;
    unmute)
      sudo -u "${DEFAULT_USER}" env "${env_args[@]}" \
        "$wpctl" set-mute @DEFAULT_AUDIO_SINK@ 0 2>/dev/null
      send_msg "$chat" "🔊 Unmuted"
      ;;
    [0-9]*)
      local pct="$value"
      pct="${pct%%%}"
      if [[ "$pct" =~ ^[0-9]+$ ]] && (( pct >= 0 && pct <= 150 )); then
        sudo -u "${DEFAULT_USER}" env "${env_args[@]}" \
          "$wpctl" set-volume @DEFAULT_AUDIO_SINK@ "$(( pct / 100 )).$(( pct % 100 ))" 2>/dev/null
        send_msg "$chat" "🔊 Volume set to ${pct}%"
      else
        send_msg "$chat" "🔧 *Usage:* \`/volume <0-100>\`"
      fi
      ;;
    *)
      send_msg "$chat" "🔊 *Usage:*
\`/volume\` — Show volume
\`/volume 75\` — Set volume
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
