#!/usr/bin/env bash
# commands/open.sh — /open <app> [args] — smart application launcher
#
# Resolution order:
# 1. URL shortcut (github, google, reddit, etc.)
# 2. Folder shortcut (downloads, home, config, repo, etc.)
# 3. "google <query>" → search in Firefox
# 4. Known alias → resolve to binary
# 5. Exact binary name → launch
# 6. Fuzzy match against .desktop names → launch
# 7. None matched → error with suggestion
##############################################################################

_cmd_open() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  if [[ -z "$args" ]]; then
    send_msg "$chat" "🖥 *Usage:* \`/open <application|url|folder|google query> [args]\`
_Launches any application, opens URLs, folders, or searches._
_Examples:_
\`/open firefox\`
\`/open github\`
\`/open downloads\`
\`/open google nix flakes\`
\`/open terminal files\`
\`/open repo\`"
    return
  fi

  # Load the application registry (discovers .desktop files if needed)
  app_registry_load

  local first_word="${args%% *}"
  local lower_first="${first_word,,}"

  # 1. URL shortcut
  if [[ -v "URL_SHORTCUTS[$lower_first]" ]]; then
    _open_url "$chat" "${URL_SHORTCUTS[$lower_first]}"
    return
  fi

  # 2. Folder shortcut
  if [[ -v "FOLDER_SHORTCUTS[$lower_first]" ]]; then
    _open_folder "$chat" "${FOLDER_SHORTCUTS[$lower_first]}"
    return
  fi

  # 3. Google search
  if [[ "$lower_first" == "google" ]]; then
    local query="${args#* }"
    if [[ -z "$query" ]]; then
      send_msg "$chat" "🔧 *Usage:* \`/open google <search query>\`
_Example:_ \`/open google nix flakes\`"
      return
    fi
    local encoded
    encoded="$(urlencode "$query")"
    _open_url "$chat" "https://www.google.com/search?q=${encoded}"
    return
  fi

  # 4-6. Try to resolve as application
  local bin
  if bin="$(app_resolve "$first_word")"; then
    # If there are remaining args, pass them through
    local remaining="${args#"$first_word"}"
    remaining="${remaining# }"
    if [[ -n "$remaining" ]]; then
      desktop::launch_app "$chat" "${bin} ${remaining}"
    else
      desktop::launch_app "$chat" "$bin"
    fi
    return
  fi

  # 7. Not found — try launching the raw input (user might know a binary we don't)
  send_msg "$chat" "❌ \`${first_word}\` not found in registry or PATH.
${sep}
Send \`/apps\` to see available applications.
Or try \`/run ${args}\` to execute as a shell command."
}

register_command "open" "_cmd_open" "🖥 Launch any application"
