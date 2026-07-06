##############################################################################
#
# Bitwarden Search & Helpers
#
# Purpose
# -------
# Interactive vault search with fzf/rofi/wofi, action menu, and
# convenience commands (bwfind, bwp, bwuser, bwpass, bwuri, bwnotes).
# Supports colored output, icons, favorites, and recent entries.
#
# NOTE: All jq operations read directly from $BW_CACHE_FILE to avoid
# shell variable capture mangling literal newlines in JSON strings.
#
##############################################################################

{ config, pkgs, lib, ... }:

let
  cfg = config.ivali.bitwarden;
in
{
  config = lib.mkIf cfg.enable {
    programs.zsh.initContent = lib.mkAfter ''
      # ═══════════════════════════════════════════════════════════════════════
      # Search Tool Detection
      # ═══════════════════════════════════════════════════════════════════════

      _bw_select() {
        local prompt="''${1:-Select}"
        local tool="${cfg.searchTool}"

        if [ "$tool" = "auto" ]; then
          if command -v rofi >/dev/null 2>&1; then
            tool="rofi"
          elif command -v wofi >/dev/null 2>&1; then
            tool="wofi"
          elif command -v fzf >/dev/null 2>&1; then
            tool="fzf"
          else
            echo "Error: No selection tool found (install fzf, rofi, or wofi)" >&2
            return 1
          fi
        fi

        case "$tool" in
          rofi)
            rofi -dmenu -i -p "$prompt" -mesg "Select a vault item" -width 60
            ;;
          wofi)
            wofi --dmenu -i -p "$prompt"
            ;;
          fzf)
            fzf --height 40% --reverse --prompt="$prompt: " \
                --border --info=inline \
                --color=fg:#c0c0c0,hl:#ff6b6b,fg+:#ffffff,hl+:#ff6b6b,pointer:#ffd93d
            ;;
          *)
            echo "Error: Unknown tool '$tool'" >&2
            return 1
            ;;
        esac
      }

      # ═══════════════════════════════════════════════════════════════════════
      # Core Search Engine
      # ═══════════════════════════════════════════════════════════════════════

      _bw_format_item() {
        ${pkgs.jq}/bin/jq -r '
          .[] |
          if .type == 1 then "🔑"
          elif .type == 2 then "💳"
          elif .type == 3 then "🔒"
          elif .type == 4 then "📝"
          elif .type == 5 then "📁"
          else "📄"
          end
          as $icon |
          # Build query: lowercase, keep only alphanum and dots, first 25 chars
          (.name | ascii_downcase | gsub("[^a-z0-9.]"; "") | .[0:25]) as $q |
          $icon + " " + .name +
          (if .login.username != null then " (" + .login.username + ")" else "" end) +
          (if .type == 1 then " [bwe:$q] [bwp:$q]"
           elif .type == 4 then " [bwn:$q]"
           else " [" + .id + "]"
           end)
        '
      }

      _bw_item_icon() {
        local item_type="$1"
        case "$item_type" in
          1) echo "🔑" ;;  # Login
          2) echo "💳" ;;  # Card
          3) echo "🔒" ;;  # Identity
          4) echo "📝" ;;  # Secure Note
          5) echo "📁" ;;  # Folder
          *) echo "📄" ;;
        esac
      }

      _bw_ensure_cache() {
        if [ ! -f "$BW_CACHE_FILE" ] || [ ! -f "$BW_CACHE_TIME" ]; then
          bw_cache_update 2>/dev/null
        fi
        [ -f "$BW_CACHE_FILE" ]
      }

      bw-search() {
        local query="$1"

        if ! _bw_ensure_cache; then
          echo "Error: No vault items found. Run: bwsync" >&2
          return 1
        fi

        # Build display list
        local display_list=""
        ${lib.optionalString cfg.enableFavorites ''
          local fav_list
          fav_list=$(bw_list_fav_ids 2>/dev/null || true)
          if [ -n "$fav_list" ]; then
            while IFS= read -r fav_id; do
              local fav_entry
              fav_entry=$(${pkgs.jq}/bin/jq -r --arg id "$fav_id" '
                .[] | select(.id == $id) |
                (.name | ascii_downcase | gsub("[^a-z0-9.]"; "") | .[0:25]) as $q |
                "⭐ " + .name +
                (if .login.username != null then " (" + .login.username + ")" else "" end) +
                (if .type == 1 then " [bwe:" + $q + "] [bwp:" + $q + "]"
                 elif .type == 4 then " [bwn:" + $q + "]"
                 else " [" + .id + "]"
                 end)
              ' "$BW_CACHE_FILE" 2>/dev/null)
              [ -n "$fav_entry" ] && display_list="$display_list$fav_entry"$'\n'
            done <<< "$fav_list"
          fi
        ''}

        ${lib.optionalString cfg.enableRecent ''
          if [ -f "$BW_RECENT_FILE" ]; then
            while IFS= read -r recent_id; do
              [ -z "$recent_id" ] && continue
              local recent_entry
              recent_entry=$(${pkgs.jq}/bin/jq -r --arg id "$recent_id" '
                .[] | select(.id == $id) |
                (.name | ascii_downcase | gsub("[^a-z0-9.]"; "") | .[0:25]) as $q |
                "🕐 " + .name +
                (if .login.username != null then " (" + .login.username + ")" else "" end) +
                (if .type == 1 then " [bwe:" + $q + "] [bwp:" + $q + "]"
                 elif .type == 4 then " [bwn:" + $q + "]"
                 else " [" + .id + "]"
                 end)
              ' "$BW_CACHE_FILE" 2>/dev/null)
              [ -n "$recent_entry" ] && display_list="$display_list$recent_entry"$'\n'
            done < "$BW_RECENT_FILE"
          fi
        ''}

        local all_items
        all_items=$(${pkgs.jq}/bin/jq -r '
          .[] |
          if .type == 1 then "🔑"
          elif .type == 2 then "💳"
          elif .type == 3 then "🔒"
          elif .type == 4 then "📝"
          elif .type == 5 then "📁"
          else "📄"
          end
          as $icon |
          (.name | ascii_downcase | gsub("[^a-z0-9.]"; "") | .[0:25]) as $q |
          $icon + " " + .name +
          (if .login.username != null then " (" + .login.username + ")" else "" end) +
          (if .type == 1 then " [bwe:$q] [bwp:$q]"
           elif .type == 4 then " [bwn:$q]"
           else " [" + .id + "]"
           end)
        ' "$BW_CACHE_FILE" 2>/dev/null)
        display_list="$display_list$all_items"

        # Deduplicate
        display_list=$(echo "$display_list" | ${pkgs.coreutils}/bin/sort -u)

        # Filter by query
        if [ -n "$query" ]; then
          display_list=$(echo "$display_list" | ${pkgs.gnugrep}/bin/grep -i "$query")
        fi

        # Present to user
        local selected
        selected=$(echo "$display_list" | _bw_select "Select item")

        if [ -z "$selected" ]; then
          return 1
        fi

        # Extract item ID — try UUID first, then command:query format
        local item_id
        item_id=$(echo "$selected" | ${pkgs.gnugrep}/bin/grep -o '[a-f0-9-]\{36\}')

        if [ -z "$item_id" ]; then
          # Try command:query format — extract query and find item by sanitized name
          local bw_query
          bw_query=$(echo "$selected" | ${pkgs.gnugrep}/bin/grep -oE '\[(bwe|bwp|bwn):[^]]+\]' | head -1 | ${pkgs.gnused}/bin/sed 's/.*://;s/\]//')
          if [ -n "$bw_query" ]; then
            item_id=$(${pkgs.jq}/bin/jq -r --arg q "$bw_query" \
              '.[] | select(.name | ascii_downcase | gsub("[^a-z0-9.]"; "") | startswith($q)) | .id' "$BW_CACHE_FILE" 2>/dev/null | head -1)
          fi
        fi

        if [ -z "$item_id" ]; then
          echo "Error: Could not extract item ID" >&2
          return 1
        fi

        # Track recent
        ${lib.optionalString cfg.enableRecent ''bw_add_recent "$item_id" 2>/dev/null''}

        echo "$item_id"
      }

      # ═══════════════════════════════════════════════════════════════════════
      # Action Menu
      # ═══════════════════════════════════════════════════════════════════════

      bw-action() {
        local item_id="$1"
        if [ -z "$item_id" ]; then
          echo "Error: No item specified" >&2
          return 1
        fi

        if ! _bw_ensure_cache; then
          echo "Error: No vault items found." >&2
          return 1
        fi

        local item_name item_username item_uri item_notes
        item_name=$(${pkgs.jq}/bin/jq -r --arg id "$item_id" '.[] | select(.id == $id) | .name' "$BW_CACHE_FILE" 2>/dev/null)
        item_username=$(${pkgs.jq}/bin/jq -r --arg id "$item_id" '.[] | select(.id == $id) | .login.username // empty' "$BW_CACHE_FILE" 2>/dev/null)
        item_uri=$(${pkgs.jq}/bin/jq -r --arg id "$item_id" '.[] | select(.id == $id) | .login.uris[0].uri // empty' "$BW_CACHE_FILE" 2>/dev/null)
        item_notes=$(${pkgs.jq}/bin/jq -r --arg id "$item_id" '.[] | select(.id == $id) | .notes // empty' "$BW_CACHE_FILE" 2>/dev/null)

        if [ -z "$item_name" ]; then
          echo "Error: Item not found" >&2
          return 1
        fi

        echo "=== $item_name ==="
        local prompt="[e]mail  [p]assword  [u]ri  [n]otes  [d]etails: "
        local choice
        read -r -p "$prompt" choice 2>/dev/null
        echo

        case "$choice" in
          e|E)
            [ -n "$item_username" ] && bw-clipboard "$item_username" "${toString cfg.clipboardTimeout}" "Email" || echo "No email found."
            ;;
          p|P)
            if [ -f "$BW_SESSION_FILE" ]; then
              export BW_SESSION="''${BW_SESSION:-$(<"$BW_SESSION_FILE")}"
            fi
            local password
            password=$(${pkgs.bitwarden-cli}/bin/bw get password "$item_id" 2>/dev/null)
            if [ -z "$password" ]; then
              ${pkgs.bitwarden-cli}/bin/bw sync 2>/dev/null
              password=$(${pkgs.bitwarden-cli}/bin/bw get password "$item_id" 2>/dev/null)
            fi
            if [ -n "$password" ]; then
              bw-clipboard "$password" "${toString cfg.clipboardTimeout}" "Password"
            else
              echo "Error: Could not get password. Try: bwunlock" >&2
            fi
            ;;
          u|U)
            [ -n "$item_uri" ] && bw-clipboard "$item_uri" "${toString cfg.clipboardTimeout}" "URI" || echo "No URI found."
            ;;
          n|N)
            [ -n "$item_notes" ] && bw-clipboard "$item_notes" "${toString cfg.clipboardTimeout}" "Notes" || echo "No notes found."
            ;;
          d|D)
            ${pkgs.bitwarden-cli}/bin/bw get item "$item_id" 2>/dev/null | ${pkgs.jq}/bin/jq '.'
            ;;
          *)
            echo "Cancelled."
            ;;
        esac
      }

      # ═══════════════════════════════════════════════════════════════════════
      # Helper Commands — All read from $BW_CACHE_FILE directly
      # ═══════════════════════════════════════════════════════════════════════

      bwfind() {
        local item_id
        item_id=$(bw-search "$*")
        if [ -z "$item_id" ]; then
          return 1
        fi

        if ! _bw_ensure_cache; then
          echo "Error: No vault items found." >&2
          return 1
        fi

        local name email
        name=$(${pkgs.jq}/bin/jq -r --arg id "$item_id" '.[] | select(.id == $id) | .name' "$BW_CACHE_FILE" 2>/dev/null)
        email=$(${pkgs.jq}/bin/jq -r --arg id "$item_id" '.[] | select(.id == $id) | .login.username // empty' "$BW_CACHE_FILE" 2>/dev/null)

        # Ensure BW_SESSION is exported for bw CLI
        if [ -f "$BW_SESSION_FILE" ]; then
          export BW_SESSION="''${BW_SESSION:-$(<"$BW_SESSION_FILE")}"
        fi

        local password
        password=$(${pkgs.bitwarden-cli}/bin/bw get password "$item_id" 2>/dev/null)
        if [ -z "$password" ]; then
          echo "Session stale, syncing..." >&2
          ${pkgs.bitwarden-cli}/bin/bw sync 2>/dev/null
          password=$(${pkgs.bitwarden-cli}/bin/bw get password "$item_id" 2>/dev/null)
        fi
        if [ -z "$password" ]; then
          echo "Error: Could not get password. Try: bwunlock" >&2
          return 1
        fi

        bw-clipboard "$password" "${toString cfg.clipboardTimeout}" "Password"

        ${lib.optionalString cfg.enableRecent ''bw_add_recent "$item_id" 2>/dev/null''}

        echo "✓ Password copied for $name (${toString cfg.clipboardTimeout}s)"
        [ -n "$email" ] && echo "  Email: $email"
      }

      bwp() {
        local query="$*"
        if [ -z "$query" ]; then
          echo "Usage: bwp <search-query>" >&2
          return 1
        fi

        if ! _bw_ensure_cache; then
          echo "Error: No vault items found. Run: bwsync" >&2
          return 1
        fi

        local matches
        matches=$(${pkgs.jq}/bin/jq -r --arg q "$query" \
          '[.[] | select(.name | test($q; "i"))] | length' "$BW_CACHE_FILE" 2>/dev/null)

        if [ "$matches" = "0" ]; then
          echo "Error: No items match '$query'" >&2
          return 1
        fi

        if [ "$matches" = "1" ]; then
          local item_id
          item_id=$(${pkgs.jq}/bin/jq -r --arg q "$query" \
            '.[] | select(.name | test($q; "i")) | .id' "$BW_CACHE_FILE" 2>/dev/null | head -1)
          bw_copy_field "$item_id" "password" "Password"
          ${lib.optionalString cfg.enableRecent ''bw_add_recent "$item_id" 2>/dev/null''}
        else
          local item_id
          item_id=$(bw-search "$query")
          if [ -n "$item_id" ]; then
            bw_copy_field "$item_id" "password" "Password"
          fi
        fi
      }

      bwuser() {
        local query="$*"
        if [ -z "$query" ]; then
          echo "Usage: bwuser <search-query>" >&2
          return 1
        fi

        if ! _bw_ensure_cache; then
          echo "Error: No vault items found. Run: bwsync" >&2
          return 1
        fi

        local matches
        matches=$(${pkgs.jq}/bin/jq -r --arg q "$query" \
          '[.[] | select(.name | test($q; "i"))] | length' "$BW_CACHE_FILE" 2>/dev/null)

        if [ "$matches" = "0" ]; then
          echo "Error: No items match '$query'" >&2
          return 1
        fi

        local item_id
        if [ "$matches" = "1" ]; then
          item_id=$(${pkgs.jq}/bin/jq -r --arg q "$query" \
            '.[] | select(.name | test($q; "i")) | .id' "$BW_CACHE_FILE" 2>/dev/null | head -1)
        else
          item_id=$(bw-search "$query")
        fi

        [ -n "$item_id" ] && bw_copy_field "$item_id" "username" "Username"
      }

      bwpass() {
        bwp "$@"
      }

      bwe() {
        local query="$*"
        if [ -z "$query" ]; then
          echo "Usage: bwe <search-query>" >&2
          return 1
        fi

        if ! _bw_ensure_cache; then
          echo "Error: No vault items found. Run: bwsync" >&2
          return 1
        fi

        local matches
        matches=$(${pkgs.jq}/bin/jq -r --arg q "$query" \
          '[.[] | select(.name | test($q; "i"))] | length' "$BW_CACHE_FILE" 2>/dev/null)

        if [ "$matches" = "0" ]; then
          echo "Error: No items match '$query'" >&2
          return 1
        fi

        if [ "$matches" = "1" ]; then
          local item_id
          item_id=$(${pkgs.jq}/bin/jq -r --arg q "$query" \
            '.[] | select(.name | test($q; "i")) | .id' "$BW_CACHE_FILE" 2>/dev/null | head -1)
          bw_copy_field "$item_id" "username" "Email"
          ${lib.optionalString cfg.enableRecent ''bw_add_recent "$item_id" 2>/dev/null''}
        else
          local item_id
          item_id=$(bw-search "$query")
          if [ -n "$item_id" ]; then
            bw_copy_field "$item_id" "username" "Email"
          fi
        fi
      }

      bwuri() {
        local query="$*"
        if [ -z "$query" ]; then
          echo "Usage: bwuri <search-query>" >&2
          return 1
        fi

        if ! _bw_ensure_cache; then
          echo "Error: No vault items found. Run: bwsync" >&2
          return 1
        fi

        local matches
        matches=$(${pkgs.jq}/bin/jq -r --arg q "$query" \
          '[.[] | select(.name | test($q; "i"))] | length' "$BW_CACHE_FILE" 2>/dev/null)

        if [ "$matches" = "0" ]; then
          echo "Error: No items match '$query'" >&2
          return 1
        fi

        local item_id
        if [ "$matches" = "1" ]; then
          item_id=$(${pkgs.jq}/bin/jq -r --arg q "$query" \
            '.[] | select(.name | test($q; "i")) | .id' "$BW_CACHE_FILE" 2>/dev/null | head -1)
        else
          item_id=$(bw-search "$query")
        fi

        [ -n "$item_id" ] && bw_copy_field "$item_id" "uri" "URI"
      }

      bwnotes() {
        local query="$*"
        if [ -z "$query" ]; then
          echo "Usage: bwnotes <search-query>" >&2
          return 1
        fi

        if ! _bw_ensure_cache; then
          echo "Error: No vault items found. Run: bwsync" >&2
          return 1
        fi

        local matches
        matches=$(${pkgs.jq}/bin/jq -r --arg q "$query" \
          '[.[] | select(.name | test($q; "i"))] | length' "$BW_CACHE_FILE" 2>/dev/null)

        if [ "$matches" = "0" ]; then
          echo "Error: No items match '$query'" >&2
          return 1
        fi

        local item_id
        if [ "$matches" = "1" ]; then
          item_id=$(${pkgs.jq}/bin/jq -r --arg q "$query" \
            '.[] | select(.name | test($q; "i")) | .id' "$BW_CACHE_FILE" 2>/dev/null | head -1)
        else
          item_id=$(bw-search "$query")
        fi

        [ -n "$item_id" ] && bw_copy_field "$item_id" "notes" "Notes"
      }

      # ═══════════════════════════════════════════════════════════════════════
      # Item Details
      # ═══════════════════════════════════════════════════════════════════════

      bw-get-item() {
        local query="$*"
        if [ -z "$query" ]; then
          echo "Usage: bw-get-item <search-query>" >&2
          return 1
        fi

        if ! _bw_ensure_cache; then
          echo "Error: No vault items found. Run: bwsync" >&2
          return 1
        fi

        local item_id
        local matches
        matches=$(${pkgs.jq}/bin/jq -r --arg q "$query" \
          '[.[] | select(.name | test($q; "i"))] | length' "$BW_CACHE_FILE" 2>/dev/null)

        if [ "$matches" = "0" ]; then
          echo "Error: No items match '$query'" >&2
          return 1
        fi

        if [ "$matches" = "1" ]; then
          item_id=$(${pkgs.jq}/bin/jq -r --arg q "$query" \
            '.[] | select(.name | test($q; "i")) | .id' "$BW_CACHE_FILE" 2>/dev/null | head -1)
        else
          item_id=$(bw-search "$query")
        fi

        [ -z "$item_id" ] && return 1

        ${pkgs.bitwarden-cli}/bin/bw get item "$item_id" 2>/dev/null | ${pkgs.jq}/bin/jq '.'
      }

      ${lib.optionalString cfg.enableTotp ''
        bwtotp() {
          local query="$*"
          if [ -z "$query" ]; then
            echo "Usage: bwtotp <search-query>" >&2
            return 1
          fi

          if ! _bw_ensure_cache; then
            echo "Error: No vault items found. Run: bwsync" >&2
            return 1
          fi

          local matches
          matches=$(${pkgs.jq}/bin/jq -r --arg q "$query" \
            '[.[] | select(.name | test($q; "i"))] | length' "$BW_CACHE_FILE" 2>/dev/null)

          if [ "$matches" = "0" ]; then
            echo "Error: No items match '$query'" >&2
            return 1
          fi

          local item_id
          if [ "$matches" = "1" ]; then
            item_id=$(${pkgs.jq}/bin/jq -r --arg q "$query" \
              '.[] | select(.name | test($q; "i")) | .id' "$BW_CACHE_FILE" 2>/dev/null | head -1)
          else
            item_id=$(bw-search "$query")
          fi

          [ -n "$item_id" ] && bw_copy_field "$item_id" "totp" "TOTP"
        }
      ''}

      ${lib.optionalString (!cfg.enableTotp) ''
        bwtotp() {
          echo "Error: TOTP requires Bitwarden Premium subscription" >&2
          return 1
        }
      ''}
    '';
  };
}
