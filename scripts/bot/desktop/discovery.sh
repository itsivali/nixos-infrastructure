#!/usr/bin/env bash
# desktop/discovery.sh — .desktop file parser and application discovery
#
# This module is sourced by lib/app_registry.sh during initialization.
# It provides the _parse_desktop_file function used by app_discover_all.
##############################################################################

# Parse a .desktop file and emit "Name|Exec|Categories|Comment".
# Skips NoDisplay and DBus-activated apps.
# Usage: _parse_desktop_file "/run/current-system/sw/share/applications/firefox.desktop"
_parse_desktop_file() {
  local file="$1"
  local name="" exec="" categories="" comment=""
  local nodisplay=false

  while IFS= read -r line; do
    # Skip comments and section headers
    [[ "$line" == \[* ]] && continue
    [[ "$line" == \#* ]] && continue

    local key="${line%%=*}"
    local value="${line#*=}"

    case "$key" in
      Name)          name="$value" ;;
      Exec)          exec="$value" ;;
      Categories)    categories="$value" ;;
      Comment)       comment="$value" ;;
      NoDisplay)     [[ "$value" == "true" ]] && nodisplay=true ;;
    esac
  done < "$file"

  # Skip NoDisplay apps
  [[ "$nodisplay" == true ]] && return 1

  # Skip if no exec or no name
  [[ -z "$exec" || -z "$name" ]] && return 1

  # Clean up Exec: remove field codes (%f, %u, %F, %U, etc.)
  exec="${exec%% %*}"
  # Get basename of exec path
  local bin="${exec##*/}"

  echo "${bin}|${name}|${exec}|${categories}|${comment}"
}
