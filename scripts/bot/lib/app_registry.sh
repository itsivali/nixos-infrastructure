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
  local nodisplay=false

  while IFS= read -r line; do
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

  [[ "$nodisplay" == true ]] && return 1
  [[ -z "$exec" || -z "$name" ]] && return 1

  # Clean up Exec: remove field codes (%f, %u, %F, %U, etc.)
  exec="${exec%% %*}"
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

  if [[ -f "$APP_CACHE" ]]; then
    local cache_age
    cache_age=$(( $(date +%s) - $(stat -c %Y "$APP_CACHE" 2>/dev/null || echo 0) ))
    if (( cache_age < 3600 )); then
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

  app_discover_all
  app_registry_save
  _APP_REGISTRY_LOADED=true
}

# Resolve a friendly name or alias to a binary.
app_resolve() {
  local query="${1,,}"

  if [[ -v "_APP_ALIASES[$query]" ]]; then
    echo "${_APP_ALIASES[$query]}"
    return 0
  fi

  if [[ -v "_APP_REGISTRY[$query]" ]]; then
    echo "$query"
    return 0
  fi

  local lower_query="$query"
  for bin in "${!_APP_REGISTRY[@]}"; do
    IFS='|' read -r name _exec _cats _comment <<< "${_APP_REGISTRY[$bin]}"
    local lower_name="${name,,}"
    if [[ "$lower_name" == *"$lower_query"* ]]; then
      echo "$bin"
      return 0
    fi
  done

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
app_list() {
  app_registry_load

  local sep="━━━━━━━━━━━━━━━━━━━━━━"
  local out="📱 *Discovered Applications*
${sep}
\`\`\`"

  local entries=()
  for bin in "${!_APP_REGISTRY[@]}"; do
    IFS='|' read -r name _exec categories _comment <<< "${_APP_REGISTRY[$bin]}"
    entries+=("${name}|${bin}|${categories}")
  done

  local sorted
  sorted="$(printf '%s\n' "${entries[@]}" | sort -t'|' -k1,1)"

  while IFS='|' read -r name bin cats; do
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
  app_add_alias "terminal" "kitty"
  app_add_alias "term" "kitty"
  app_add_alias "shell" "kitty"
  app_add_alias "console" "kitty"

  app_add_alias "files" "dolphin"
  app_add_alias "file" "dolphin"
  app_add_alias "dolphin" "dolphin"

  app_add_alias "browser" "firefox"
  app_add_alias "web" "firefox"

  app_add_alias "editor" "zeditor"
  app_add_alias "code" "zeditor"
  app_add_alias "zed" "zeditor"

  app_add_alias "settings" "gnome-control-center"
  app_add_alias "monitor" "btop"
  app_add_alias "disks" "gnome-disks"
  app_add_alias "btop" "btop"
  app_add_alias "htop" "htop"

  app_add_alias "localsend" "localsend_app"

  app_add_alias "libreoffice" "libreoffice"
}
