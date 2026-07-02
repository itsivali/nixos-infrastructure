#!/usr/bin/env bash
# lib/app_registry.sh — Application registry with aliases and fuzzy matching
#
# Dependencies: lib/core.sh (log)
# Provides:     app_registry_load, app_resolve, app_list, app_add_alias,
#               app_add_entry, app_discover_all
##############################################################################

# Internal registry: binary → "Name|Exec|Categories|Comment"
declare -A _APP_REGISTRY
# Friendly alias → binary name
declare -A _APP_ALIASES
# Track if registry has been loaded
_APP_REGISTRY_LOADED=false

# Add an application alias.
# Usage: app_add_alias "terminal" "kgx"
app_add_alias() {
  local alias_name="$1" binary="$2"
  _APP_ALIASES["$alias_name"]="$binary"
}

# Add an entry to the application registry.
# Usage: app_add_entry "firefox" "Firefox|firefox %u|Network;WebBrowser;|Browse the web"
app_add_entry() {
  local binary="$1" data="$2"
  _APP_REGISTRY["$binary"]="$data"
}

# Parse a single .desktop file and extract Name, Exec, Categories, Comment.
_parse_desktop_file() {
  local file="$1"
  local name="" exec="" categories="" comment=""

  while IFS='=' read -r key value; do
    case "$key" in
      Name) name="$value" ;;
      Exec) exec="$value" ;;
      Categories) categories="$value" ;;
      Comment) comment="$value" ;;
    esac
  done < "$file"

  # Skip NoDisplay and DBus-activated apps
  grep -q "^NoDisplay=true" "$file" 2>/dev/null && return 1
  grep -q "^DBusActivatable=true" "$file" 2>/dev/null && return 1

  # Skip if no exec or no name
  [[ -z "$exec" || -z "$name" ]] && return 1

  # Clean up Exec: remove %f, %u, field codes
  exec="${exec%% %*}"
  # Get basename of exec path
  local bin="${exec##*/}"

  echo "${bin}|${name}|${exec}|${categories}|${comment}"
}

# Discover applications from .desktop files and populate the registry.
app_discover_all() {
  local count=0

  for dir in "${DESKTOP_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    for desktop_file in "$dir"/*.desktop; do
      [[ -f "$desktop_file" ]] || continue
      local entry
      if entry="$(_parse_desktop_file "$desktop_file")"; then
        local bin="${entry%%|*}"
        if [[ -n "$bin" && -z "${_APP_REGISTRY[$bin]:-}" ]]; then
          _APP_REGISTRY["$bin"]="$entry"
          (( count++ ))
        fi
      fi
    done
  done

  log "app_registry: discovered ${count} applications"
}

# Save the registry to a JSON cache file.
app_registry_save() {
  local json='['
  local first=true
  for bin in "${!_APP_REGISTRY[@]}"; do
    IFS='|' read -r _b name exec categories comment <<< "${_APP_REGISTRY[$bin]}"
    if [[ "$first" == true ]]; then
      first=false
    else
      json+=','
    fi
    # Escape JSON strings
    name="${name//\"/\\\"}"
    exec="${exec//\"/\\\"}"
    categories="${categories//\"/\\\"}"
    comment="${comment//\"/\\\"}"
    json+="{\"binary\":\"${bin}\",\"name\":\"${name}\",\"exec\":\"${exec}\",\"categories\":\"${categories}\",\"comment\":\"${comment}\"}"
  done
  json+=']'

  echo "$json" > "${APP_CACHE}.tmp" && mv "${APP_CACHE}.tmp" "$APP_CACHE"
}

# Load the registry from cache, or discover fresh if cache is missing/stale.
app_registry_load() {
  [[ "$_APP_REGISTRY_LOADED" == true ]] && return 0

  # Load aliases first
  _load_aliases

  # Check if cache exists and is less than 1 hour old
  if [[ -f "$APP_CACHE" ]]; then
    local cache_age
    cache_age=$(( $(date +%s) - $(stat -c %Y "$APP_CACHE" 2>/dev/null || echo 0) ))
    if (( cache_age < 3600 )); then
      # Load from cache
      local count=0
      while IFS= read -r line; do
        local bin name exec categories comment
        bin="$(echo "$line" | jq -r '.binary')"
        name="$(echo "$line" | jq -r '.name')"
        exec="$(echo "$line" | jq -r '.exec')"
        categories="$(echo "$line" | jq -r '.categories')"
        comment="$(echo "$line" | jq -r '.comment')"
        _APP_REGISTRY["$bin"]="${name}|${exec}|${categories}|${comment}"
        (( count++ ))
      done < <(jq -c '.[]' "$APP_CACHE" 2>/dev/null)
      log "app_registry: loaded ${count} apps from cache"
      _APP_REGISTRY_LOADED=true
      return 0
    fi
  fi

  # Discover fresh
  app_discover_all
  app_registry_save
  _APP_REGISTRY_LOADED=true
}

# Resolve a friendly name or alias to a binary.
# Returns 0 and prints binary name if found, returns 1 if not found.
# Usage: bin="$(app_resolve "terminal")" || echo "not found"
app_resolve() {
  local query="${1,,}"  # lowercase

  # 1. Check exact alias match
  if [[ -v "_APP_ALIASES[$query]" ]]; then
    echo "${_APP_ALIASES[$query]}"
    return 0
  fi

  # 2. Check exact binary match in registry
  if [[ -v "_APP_REGISTRY[$query]" ]]; then
    echo "$query"
    return 0
  fi

  # 3. Check against Name field (case-insensitive)
  local lower_query="$query"
  for bin in "${!_APP_REGISTRY[@]}"; do
    IFS='|' read -r name _exec _cats _comment <<< "${_APP_REGISTRY[$bin]}"
    local lower_name="${name,,}"
    if [[ "$lower_name" == *"$lower_query"* ]]; then
      echo "$bin"
      return 0
    fi
  done

  # 4. Fuzzy match: check if query is a substring of any name
  for bin in "${!_APP_REGISTRY[@]}"; do
    IFS='|' read -r name _exec _cats _comment <<< "${_APP_REGISTRY[$bin]}"
    local lower_name="${name,,}"
    if [[ "$lower_name" == *"$lower_query"* ]]; then
      echo "$bin"
      return 0
    fi
  done

  return 1
}

# List all known applications in a formatted string.
# Usage: send_long "$chat" "$(app_list)"
app_list() {
  app_registry_load

  local sep="━━━━━━━━━━━━━━━━━━━━━━"
  local out="📱 *Discovered Applications*
${sep}
\`\`\`"

  # Collect and sort by name
  local entries=()
  for bin in "${!_APP_REGISTRY[@]}"; do
    IFS='|' read -r name _exec categories _comment <<< "${_APP_REGISTRY[$bin]}"
    entries+=("${name}|${bin}|${categories}")
  done

  # Sort by name field
  local sorted
  sorted="$(printf '%s\n' "${entries[@]}" | sort -t'|' -k1,1)"

  while IFS='|' read -r name bin cats; do
    # Truncate long names
    local display_name="${name:0:20}"
    local display_bin="${bin:0:16}"
    printf -v line "  %-20s %-16s %s" "$display_name" "$display_bin" "${cats:0:30}"
    out+=$'\n'"${line}"
  done <<< "$sorted"

  out+=$'\n'"~~~"
  out+=$'\n'"${sep}"
  out+=$'\n'"_Use \`/open <name>\` to launch any app._"

  echo "$out"
}

# Load the alias mappings.
_load_aliases() {
  # Terminal
  app_add_alias "terminal" "kgx"
  app_add_alias "term" "kgx"
  app_add_alias "shell" "kgx"
  app_add_alias "console" "kgx"

  # File manager
  app_add_alias "files" "nautilus"
  app_add_alias "file" "nautilus"
  app_add_alias "nautilus" "nautilus"

  # Browser
  app_add_alias "browser" "firefox"
  app_add_alias "web" "firefox"

  # Editors
  app_add_alias "editor" "zeditor"
  app_add_alias "code" "zeditor"
  app_add_alias "zed" "zeditor"

  # System tools
  app_add_alias "settings" "gnome-control-center"
  app_add_alias "monitor" "gnome-system-monitor"
  app_add_alias "disks" "gnome-disks"
  app_add_alias "camera" "snapshot"
  app_add_alias "extensions" "extension-manager"
  app_add_alias "tweaks" "gnome-tweaks"
  app_add_alias "calculator" "gnome-calculator"
  app_add_alias "btop" "btop"
  app_add_alias "htop" "htop"

  # Network
  app_add_alias "localsend" "localsend_app"

  # Office
  app_add_alias "libreoffice" "libreoffice"
}
