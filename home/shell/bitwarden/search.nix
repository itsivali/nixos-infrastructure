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
          $icon + " " + .name +
          (if .login.username != null then " (" + .login.username + ")" else "" end) +
          " [" + .id + "]"
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

      bw-search() {
        local query="$1"
        local items
        items=$(bw-cache get)

        if [ -z "$items" ] || [ "$items" = "null" ]; then
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
              fav_entry=$(echo "$items" | ${pkgs.jq}/bin/jq -r --arg id "$fav_id" \
                '.[] | select(.id == $id) | "⭐ " + .name + (if .login.username != null then " (" + .login.username + ")" else "" end) + " [" + .id + "]"' 2>/dev/null)
              [ -n "$fav_entry" ] && display_list="$display_list$fav_entry"$'\n'
            done <<< "$fav_list"
          fi
        ''}

        ${lib.optionalString cfg.enableRecent ''
          if [ -f "$BW_RECENT_FILE" ]; then
            while IFS= read -r recent_id; do
              [ -z "$recent_id" ] && continue
              local recent_entry
              recent_entry=$(echo "$items" | ${pkgs.jq}/bin/jq -r --arg id "$recent_id" \
                '.[] | select(.id == $id) | "🕐 " + .name + (if .login.username != null then " (" + .login.username + ")" else "" end) + " [" + .id + "]"' 2>/dev/null)
              [ -n "$recent_entry" ] && display_list="$display_list$recent_entry"$'\n'
            done < "$BW_RECENT_FILE"
          fi
        ''}

        local all_items
        all_items=$(echo "$items" | _bw_format_item)
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

        # Extract ID
        local item_id
        item_id=$(echo "$selected" | ${pkgs.gnugrep}/bin/grep -o '[a-f0-9-]\{36\}')

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

        # Get item details
        local item
        item=$(${pkgs.bitwarden-cli}/bin/bw get item "$item_id" 2>/dev/null)
        if [ -z "$item" ]; then
          echo "Error: Could not fetch item" >&2
          return 1
        fi

        local item_name
        item_name=$(echo "$item" | ${pkgs.jq}/bin/jq -r '.name')

        # Build action menu
        local actions=""
        actions="1) Copy Username"$'\n'
        actions="$actions 2) Copy Password"$'\n'
        ${lib.optionalString cfg.enableTotp ''actions="$actions 3) Copy TOTP"$'\n''}
        actions="$actions 4) Copy URI"$'\n'
        actions="$actions 5) Copy Notes"$'\n'
        actions="$actions 6) Show Details"$'\n'

        echo "=== $item_name ==="
        local choice
        choice=$(echo "$actions" | _bw_select "Action")

        case "$choice" in
          *"Copy Username"*)
            local username
            username=$(echo "$item" | ${pkgs.jq}/bin/jq -r '.login.username // empty')
            if [ -z "$username" ]; then
              echo "Error: No username found" >&2
              return 1
            fi
            bw-clipboard "$username" "${toString cfg.clipboardTimeout}" "Username"
            ;;
          *"Copy Password"*)
            local password
            password=$(${pkgs.bitwarden-cli}/bin/bw get password "$item_id" 2>/dev/null)
            if [ -z "$password" ]; then
              echo "Error: No password found" >&2
              return 1
            fi
            bw-clipboard "$password" "${toString cfg.clipboardTimeout}" "Password"
            ;;
          *"Copy TOTP"*)
            ${lib.optionalString cfg.enableTotp ''
              local totp
              totp=$(${pkgs.bitwarden-cli}/bin/bw get totp "$item_id" 2>/dev/null)
              if [ -z "$totp" ]; then
                echo "Error: TOTP not available (requires Bitwarden Premium)" >&2
                return 1
              fi
              bw-clipboard "$totp" 30 "TOTP"
            ''}
            ${lib.optionalString (!cfg.enableTotp) ''
              echo "Error: TOTP requires Bitwarden Premium subscription" >&2
              return 1
            ''}
            ;;
          *"Copy URI"*)
            local uri
            uri=$(echo "$item" | ${pkgs.jq}/bin/jq -r '.login.uris[0].uri // empty')
            if [ -z "$uri" ]; then
              echo "Error: No URI found" >&2
              return 1
            fi
            bw-clipboard "$uri" "${toString cfg.clipboardTimeout}" "URI"
            ;;
          *"Copy Notes"*)
            local notes
            notes=$(echo "$item" | ${pkgs.jq}/bin/jq -r '.notes // empty')
            if [ -z "$notes" ]; then
              echo "Error: No notes found" >&2
              return 1
            fi
            bw-clipboard "$notes" "${toString cfg.clipboardTimeout}" "Notes"
            ;;
          *"Show Details"*)
            echo "$item" | ${pkgs.jq}/bin/jq '.'
            ;;
          *)
            echo "Cancelled."
            ;;
        esac
      }

      # ═══════════════════════════════════════════════════════════════════════
      # Helper Commands
      # ═══════════════════════════════════════════════════════════════════════

      bwfind() {
        local item_id
        item_id=$(bw-search "$*")
        [ -n "$item_id" ] && bw-action "$item_id"
      }

      bwp() {
        local query="$*"
        if [ -z "$query" ]; then
          echo "Usage: bwp <search-query>" >&2
          return 1
        fi

        local items
        items=$(bw-cache get)

        # Filter matching items
        local matches
        matches=$(echo "$items" | ${pkgs.jq}/bin/jq -r --arg q "$query" \
          '[.[] | select(.name | test($q; "i"))] | length' 2>/dev/null)

        if [ "$matches" = "0" ]; then
          echo "Error: No items match '$query'" >&2
          return 1
        fi

        if [ "$matches" = "1" ]; then
          # Single match: copy password directly
          local item_id
          item_id=$(echo "$items" | ${pkgs.jq}/bin/jq -r --arg q "$query" \
            '.[] | select(.name | test($q; "i")) | .id' 2>/dev/null | head -1)
          bw_copy_field "$item_id" "password" "Password"
          ${lib.optionalString cfg.enableRecent ''bw_add_recent "$item_id" 2>/dev/null''}
        else
          # Multiple matches: show fzf
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

        local items
        items=$(bw-cache get)
        local matches
        matches=$(echo "$items" | ${pkgs.jq}/bin/jq -r --arg q "$query" \
          '[.[] | select(.name | test($q; "i"))] | length' 2>/dev/null)

        if [ "$matches" = "0" ]; then
          echo "Error: No items match '$query'" >&2
          return 1
        fi

        local item_id
        if [ "$matches" = "1" ]; then
          item_id=$(echo "$items" | ${pkgs.jq}/bin/jq -r --arg q "$query" \
            '.[] | select(.name | test($q; "i")) | .id' 2>/dev/null | head -1)
        else
          item_id=$(bw-search "$query")
        fi

        [ -n "$item_id" ] && bw_copy_field "$item_id" "username" "Username"
      }

      bwpass() {
        bwp "$@"
      }

      bwuri() {
        local query="$*"
        if [ -z "$query" ]; then
          echo "Usage: bwuri <search-query>" >&2
          return 1
        fi

        local items
        items=$(bw-cache get)
        local matches
        matches=$(echo "$items" | ${pkgs.jq}/bin/jq -r --arg q "$query" \
          '[.[] | select(.name | test($q; "i"))] | length' 2>/dev/null)

        if [ "$matches" = "0" ]; then
          echo "Error: No items match '$query'" >&2
          return 1
        fi

        local item_id
        if [ "$matches" = "1" ]; then
          item_id=$(echo "$items" | ${pkgs.jq}/bin/jq -r --arg q "$query" \
            '.[] | select(.name | test($q; "i")) | .id' 2>/dev/null | head -1)
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

        local items
        items=$(bw-cache get)
        local matches
        matches=$(echo "$items" | ${pkgs.jq}/bin/jq -r --arg q "$query" \
          '[.[] | select(.name | test($q; "i"))] | length' 2>/dev/null)

        if [ "$matches" = "0" ]; then
          echo "Error: No items match '$query'" >&2
          return 1
        fi

        local item_id
        if [ "$matches" = "1" ]; then
          item_id=$(echo "$items" | ${pkgs.jq}/bin/jq -r --arg q "$query" \
            '.[] | select(.name | test($q; "i")) | .id' 2>/dev/null | head -1)
        else
          item_id=$(bw-search "$query")
        fi

        [ -n "$item_id" ] && bw_copy_field "$item_id" "notes" "Notes"
      }

      bwtotp() {
        ${lib.optionalString cfg.enableTotp ''
          local query="$*"
          if [ -z "$query" ]; then
            echo "Usage: bwtotp <search-query>" >&2
            return 1
          fi

          local items
          items=$(bw-cache get)
          local matches
          matches=$(echo "$items" | ${pkgs.jq}/bin/jq -r --arg q "$query" \
            '[.[] | select(.name | test($q; "i"))] | length' 2>/dev/null)

          if [ "$matches" = "0" ]; then
            echo "Error: No items match '$query'" >&2
            return 1
          fi

          local item_id
          if [ "$matches" = "1" ]; then
            item_id=$(echo "$items" | ${pkgs.jq}/bin/jq -r --arg q "$query" \
              '.[] | select(.name | test($q; "i")) | .id' 2>/dev/null | head -1)
          else
            item_id=$(bw-search "$query")
          fi

          [ -n "$item_id" ] && bw_copy_field "$item_id" "totp" "TOTP"
        ''}
        ${lib.optionalString (!cfg.enableTotp) ''
          bwtotp() {
            echo "Error: TOTP requires Bitwarden Premium subscription" >&2
            return 1
          }
        ''}
      }
    '';
  };
}
