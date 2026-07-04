# commands/clipboard.sh — /clipboard [set <text>] — clipboard operations
# Uses wl-clipboard (Wayland-native).
##############################################################################

_cmd_clipboard() {
  local chat="$1" args="$2"

  desktop::require_graphical "$chat" || return

  local wl_copy wl_paste
  wl_copy="$(desktop::resolve_binary wl-copy)" || true
  wl_paste="$(desktop::resolve_binary wl-paste)" || true

  if [[ -z "$wl_paste" || -z "$wl_copy" ]]; then
    send_msg "$chat" "❌ wl-clipboard not found on ${HOST}."
    return
  fi

  local subcmd="${args%% *}"
  local content="${args#* }"

  case "$subcmd" in
    set|"")
      if [[ "$subcmd" == "set" && -n "$content" ]]; then
        echo -n "$content" | sudo -u "${DEFAULT_USER}" \
          XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
          DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
          WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
          "$wl_copy" 2>/dev/null
        send_msg "$chat" "📋 Clipboard set to: \`${content:0:100}\`"
      else
        local clip
        clip="$(sudo -u "${DEFAULT_USER}" \
          XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
          DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
          WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
          "$wl_paste" 2>/dev/null)" || true
        if [[ -n "$clip" ]]; then
          send_long "$chat" "📋 *Clipboard:*
\`\`\`
${clip}
\`\`\`"
        else
          send_msg "$chat" "📋 Clipboard is empty."
        fi
      fi
      ;;
    *)
      send_msg "$chat" "📋 *Usage:*
\`/clipboard\` — Read clipboard
\`/clipboard set <text>\` — Set clipboard"
      ;;
  esac
}

register_command "clipboard" "_cmd_clipboard" "📋 Clipboard operations"
