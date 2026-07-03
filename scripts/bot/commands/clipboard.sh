#!/usr/bin/env bash
# commands/clipboard.sh — /clipboard [set <text>] — clipboard operations
##############################################################################

_cmd_clipboard() {
  local chat="$1" args="$2"
  local -a env_args
  session_env_args "$chat" env_args || return

  local wl_copy wl_paste
  wl_copy="$(resolve_binary wl-copy)" || true
  wl_paste="$(resolve_binary wl-paste)" || true

  if [[ -z "$wl_paste" || -z "$wl_copy" ]]; then
    send_msg "$chat" "❌ wl-clipboard not found on ${HOST}."
    return
  fi

  local subcmd="${args%% *}"
  local content="${args#* }"

  case "$subcmd" in
    set|"")
      if [[ "$subcmd" == "set" && -n "$content" ]]; then
        echo -n "$content" | sudo -u "${DEFAULT_USER}" env "${env_args[@]}" \
          "$wl_copy" 2>/dev/null
        send_msg "$chat" "📋 Clipboard set to: \`${content:0:100}\`"
      else
        local clip
        clip="$(sudo -u "${DEFAULT_USER}" env "${env_args[@]}" \
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
