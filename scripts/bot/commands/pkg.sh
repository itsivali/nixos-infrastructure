#!/usr/bin/env bash
# commands/pkg.sh — /pkg search|info — Nix package search
##############################################################################

_cmd_pkg() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  local subcmd="${args%% *}"
  local query="${args#* }"

  case "$subcmd" in
    search|s|find|f)
      if [[ -z "$query" || "$query" == "$subcmd" ]]; then
        send_msg "$chat" "🔧 *Usage:* \`/pkg search <query>\`
_Search for Nix packages._
_Example:_ \`/pkg search firefox\`"
        return
      fi

      send_typing "$chat"

      # Use nix search with JSON output for reliable parsing
      local results
      results=$(timeout 30 nix search nixpkgs#${query} --json 2>/dev/null | head -c 8000) || true

      if [[ -z "$results" ]]; then
        send_msg "$chat" "❌ No packages found for \`${query}\`."
        return
      fi

      local out="📦 *Search Results:* \`${query}\`
${sep}
"

      # Parse JSON results - each line is a separate JSON object
      local count=0
      while IFS= read -r line; do
        local name version description
        name=$(echo "$line" | jq -r '.[0] // empty' 2>/dev/null | sed 's/^legacyPackages\.x86_64-linux\.//')
        version=$(echo "$line" | jq -r '.[1].version // "?"' 2>/dev/null)
        description=$(echo "$line" | jq -r '.[1].meta.description // ""' 2>/dev/null)

        # Truncate long descriptions
        if [[ ${#description} -gt 60 ]]; then
          description="${description:0:57}..."
        fi

        if [[ -n "$name" && "$count" -lt 8 ]]; then
          out+="*${name}* \`v${version}\`
  ${description}

"
          ((count++))
        fi
      done <<< "$(echo "$results" | jq -c 'to_entries[]' 2>/dev/null)"

      if [[ "$count" -eq 0 ]]; then
        send_msg "$chat" "❌ No packages found for \`${query}\`."
        return
      fi

      out+="${sep}
_Found ${count} results. Use_ \`/pkg info <name>\` _for details._"

      send_long "$chat" "$out"
      ;;

    info|i|show)
      if [[ -z "$query" || "$query" == "$subcmd" ]]; then
        send_msg "$chat" "🔧 *Usage:* \`/pkg info <package>\`
_Show detailed package info._
_Example:_ \`/pkg info firefox\`"
        return
      fi

      send_typing "$chat"

      local info
      info=$(timeout 30 nix eval --json "nixpkgs#${query}" --apply 'x: { name = x.name; version = x.version; description = x.meta.description or ""; homepage = x.meta.homepage or ""; license = (builtins.tryEval (x.meta.license.spdxId or x.meta.license or "")).value; platforms = x.meta.platforms or []; }' 2>/dev/null) || true

      if [[ -z "$info" || "$info" == "{}" ]]; then
        send_msg "$chat" "❌ Package \`${query}\` not found."
        return
      fi

      local name version description homepage license
      name=$(echo "$info" | jq -r '.name // "?"')
      version=$(echo "$info" | jq -r '.version // "?"')
      description=$(echo "$info" | jq -r '.description // "No description"')
      homepage=$(echo "$info" | jq -r '.homepage // "N/A"')
      license=$(echo "$info" | jq -r '.license // "N/A"')

      local out="📦 *${name}* \`v${version}\`
${sep}

${description}

*Homepage:* ${homepage}
*License:* ${license}

*Install:*
\`\`\`
nix-env -iA nixpkgs.${query}
# or in configuration.nix:
# environment.systemPackages = [ pkgs.${query} ];
\`\`\`

${sep}
_Run_ \`/pkg search <query>\` _to find packages._"

      send_long "$chat" "$out"
      ;;

    *)
      send_msg "$chat" "📦 *Nix Package Tools*
━━━━━━━━━━━━━━━━━━━━━━━━━━

\`/pkg search <query>\`  Search packages
\`/pkg info <name>\`    Package details

*Examples:*
\`/pkg search firefox\`
\`/pkg info vim\`"
      ;;
  esac
}

register_command "pkg" "_cmd_pkg" "📦 Search Nix packages"
