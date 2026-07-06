##############################################################################
#
# Bitwarden Vault Cache
#
# Purpose
# -------
# Caches vault items to avoid repeated API calls.
# Manages favorites and recent entry tracking.
# Cache is stored in $XDG_RUNTIME_DIR/bitwarden/ (tmpfs, RAM-only).
# Favorites are persistent in $XDG_DATA_HOME/bitwarden/favorites.
#
##############################################################################

{ config, pkgs, lib, ... }:

let
  cfg = config.ivali.bitwarden;
in
{
  config = lib.mkIf cfg.enable {
    home.file.".local/share/bitwarden/.keep".text = "";

    programs.zsh.initContent = lib.mkAfter ''
      # ═══════════════════════════════════════════════════════════════════════
      # Vault Cache Management
      # ═══════════════════════════════════════════════════════════════════════

      BW_CACHE_FILE="$BW_RT_DIR/cache.json"
      BW_CACHE_TIME="$BW_RT_DIR/cache-time"
      BW_RECENT_FILE="$BW_RT_DIR/recent"
      BW_FAV_FILE="${config.xdg.dataHome}/bitwarden/favorites"

      bw-cache() {
        local cmd="''${1:-get}"
        case "$cmd" in
          update)  bw_cache_update ;;
          get)     bw_cache_get ;;
          invalidate) bw_cache_invalidate ;;
          *)       echo "Usage: bw-cache {update|get|invalidate}" ;;
        esac
      }

      bw_cache_update() {
        if [ -z "$BW_SESSION" ] && [ -f "$BW_SESSION_FILE" ]; then
          export BW_SESSION=$(<"$BW_SESSION_FILE")
        fi

        if [ -z "$BW_SESSION" ]; then
          echo "Error: Vault is locked. Run: bwunlock" >&2
          return 1
        fi

        local tmpfile
        tmpfile=$(mktemp)
        # Pipe directly from bw to jq to avoid shell variable mangling newlines
        bw list items 2>/dev/null | jq -c '
          [.[] | del(.key, .fido2Credentials, .passwordHistory, .attachments)]
          | sort_by(.name | ascii_downcase)
        ' > "$tmpfile" 2>/dev/null
        local count
        count=$(jq 'length' "$tmpfile" 2>/dev/null)
        if [ $? -eq 0 ] && [ "$count" != "0" ] && [ "$count" != "null" ]; then
          mv "$tmpfile" "$BW_CACHE_FILE"
          date +%s > "$BW_CACHE_TIME"
          echo "Cache updated. $count items."
        else
          rm -f "$tmpfile"
          echo "Error: Failed to fetch vault items" >&2
          return 1
        fi
      }

      bw_cache_get() {
        # Check cache freshness
        if [ -f "$BW_CACHE_TIME" ] && [ -f "$BW_CACHE_FILE" ]; then
          local cache_age
          cache_age=$(( $(date +%s) - $(<"$BW_CACHE_TIME") ))
          if [ "$cache_age" -lt ${toString cfg.cacheTtl} ]; then
            cat "$BW_CACHE_FILE"
            return 0
          fi
        fi

        # Cache stale or missing, refresh
        bw_cache_update 2>/dev/null
        if [ -f "$BW_CACHE_FILE" ]; then
          cat "$BW_CACHE_FILE"
        fi
      }

      bw_cache_invalidate() {
        rm -f "$BW_CACHE_FILE" "$BW_CACHE_TIME" 2>/dev/null
        echo "Cache invalidated."
      }

      # ═══════════════════════════════════════════════════════════════════════
      # Favorites Management
      # ═══════════════════════════════════════════════════════════════════════

      ${lib.optionalString cfg.enableFavorites ''
        mkdir -p "$(dirname "$BW_FAV_FILE")"

        bwfav() {
          local cmd="''${1:-list}"
          case "$cmd" in
            add)  bw_fav_add "''${2}" ;;
            rm)   bw_fav_rm "''${2}" ;;
            list) bw_fav_list ;;
            *)    echo "Usage: bwfav {add|rm|list} [query]" ;;
          esac
        }

        bw_fav_add() {
          local query="$1"
          if [ -z "$query" ]; then
            echo "Usage: bwfav add <query>" >&2
            return 1
          fi

          local item_id
          item_id=$(${pkgs.jq}/bin/jq -r --arg q "$query" \
            '.[] | select(.name | test($q; "i")) | .id' "$BW_CACHE_FILE" 2>/dev/null | head -1)

          if [ -z "$item_id" ]; then
            echo "Error: No item matching '$query'" >&2
            return 1
          fi

          if grep -qF "$item_id" "$BW_FAV_FILE" 2>/dev/null; then
            echo "Already in favorites."
            return 0
          fi

          echo "$item_id" >> "$BW_FAV_FILE"
          echo "Added to favorites."
        }

        bw_fav_rm() {
          local query="$1"
          if [ -z "$query" ]; then
            echo "Usage: bwfav rm <query>" >&2
            return 1
          fi

          local item_id
          item_id=$(${pkgs.jq}/bin/jq -r --arg q "$query" \
            '.[] | select(.name | test($q; "i")) | .id' "$BW_CACHE_FILE" 2>/dev/null | head -1)

          if [ -z "$item_id" ]; then
            echo "Error: No item matching '$query'" >&2
            return 1
          fi

          ${pkgs.gnused}/bin/sed -i "\|^''${item_id}$|d" "$BW_FAV_FILE" 2>/dev/null
          echo "Removed from favorites."
        }

        bw_fav_list() {
          if [ ! -f "$BW_FAV_FILE" ] || [ ! -s "$BW_FAV_FILE" ]; then
            echo "No favorites."
            return 0
          fi

          while IFS= read -r fav_id; do
            local name
            name=$(${pkgs.jq}/bin/jq -r --arg id "$fav_id" \
              '.[] | select(.id == $id) | .name' "$BW_CACHE_FILE" 2>/dev/null)
            if [ -n "$name" ]; then
              echo "⭐ $name"
            fi
          done < "$BW_FAV_FILE"
        }

        bw_is_fav() {
          local item_id="$1"
          [ -f "$BW_FAV_FILE" ] && grep -qF "$item_id" "$BW_FAV_FILE" 2>/dev/null
        }

        bw_list_fav_ids() {
          [ -f "$BW_FAV_FILE" ] && cat "$BW_FAV_FILE" 2>/dev/null
        }
      ''}

      # ═══════════════════════════════════════════════════════════════════════
      # Recent Entries
      # ═══════════════════════════════════════════════════════════════════════

      ${lib.optionalString cfg.enableRecent ''
        bw_add_recent() {
          local item_id="$1"
          if [ -z "$item_id" ] || [ ! -d "$BW_RT_DIR" ]; then
            return 0
          fi

          # Remove if already in recent
          ${pkgs.gnused}/bin/sed -i "\|^''${item_id}$|d" "$BW_RECENT_FILE" 2>/dev/null

          # Add to top
          local tmp
          tmp=$(mktemp)
          echo "$item_id" > "$tmp"
          cat "$BW_RECENT_FILE" >> "$tmp" 2>/dev/null

          # Keep only last 10
          head -10 "$tmp" > "$BW_RECENT_FILE"
          rm -f "$tmp"
        }

        bw_get_recent() {
          if [ ! -f "$BW_RECENT_FILE" ] || [ ! -s "$BW_RECENT_FILE" ]; then
            return 0
          fi

          while IFS= read -r recent_id; do
            local name
            name=$(${pkgs.jq}/bin/jq -r --arg id "$recent_id" \
              '.[] | select(.id == $id) | .name' "$BW_CACHE_FILE" 2>/dev/null)
            if [ -n "$name" ]; then
              echo "🕐 $name"
            fi
          done < "$BW_RECENT_FILE"
        }

        bw_list_recent_ids() {
          cat "$BW_RECENT_FILE" 2>/dev/null
        }
      ''}
    '';
  };
}
