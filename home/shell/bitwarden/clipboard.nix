##############################################################################
#
# Bitwarden Clipboard Abstraction
#
# Purpose
# -------
# Clipboard integration with automatic clearing, history protection,
# and notifications. Detects Wayland vs X11 and uses appropriate tool.
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
      # Clipboard Abstraction
      # ═══════════════════════════════════════════════════════════════════════

      _bw_clip_get_cmd() {
        if [ -n "$WAYLAND_DISPLAY" ]; then
          echo "${pkgs.wl-clipboard}/bin/wl-paste"
        elif [ -n "$DISPLAY" ]; then
          echo "${pkgs.xclip}/bin/xclip -selection clipboard -o"
        else
          echo ""
        fi
      }

      _bw_clip_set_cmd() {
        if [ -n "$WAYLAND_DISPLAY" ]; then
          echo "${pkgs.wl-clipboard}/bin/wl-copy"
        elif [ -n "$DISPLAY" ]; then
          echo "${pkgs.xclip}/bin/xclip -selection clipboard"
        else
          echo ""
        fi
      }

      bw-clipboard() {
        local content="$1"
        local timeout="''${2:-${toString cfg.clipboardTimeout}}"
        local label="''${3:-Bitwarden}"

        local set_cmd
        set_cmd=$(_bw_clip_set_cmd)
        if [ -z "$set_cmd" ]; then
          echo "Error: No clipboard tool found (install wl-clipboard or xclip)" >&2
          return 1
        fi

        # Save current clipboard for history protection
        local get_cmd
        get_cmd=$(_bw_clip_get_cmd)
        local old_clip=""
        if [ -n "$get_cmd" ]; then
          old_clip=$(eval "$get_cmd" 2>/dev/null || true)
        fi

        # Copy to clipboard
        echo -n "$content" | eval "$set_cmd"

        # Auto-clear in background with history protection
        if [ "$timeout" -gt 0 ] 2>/dev/null; then
          (
            sleep "$timeout"
            get_cmd=$(_bw_clip_get_cmd)
            set_cmd=$(_bw_clip_set_cmd)
            if [ -n "$get_cmd" ] && [ -n "$set_cmd" ]; then
              current_clip=$(eval "$get_cmd" 2>/dev/null || true)
              if [ "$current_clip" = "$content" ]; then
                if [ -n "$old_clip" ]; then
                  printf '%s' "$old_clip" | eval "$set_cmd"
                else
                  printf "" | eval "$set_cmd"
                fi
              fi
            fi
          ) &
        fi

        # Notification
        bw-notify "$label copied (clears in $timeout s)"
      }

      # ═══════════════════════════════════════════════════════════════════════
      # Clipboard Field Shortcuts
      # ═══════════════════════════════════════════════════════════════════════

      bw_copy_field() {
        local item_id="$1"
        local field="$2"
        local label="$3"

        if [ -z "$item_id" ]; then
          echo "Error: No item specified" >&2
          return 1
        fi

        local value
        case "$field" in
          password)
            value=$(${pkgs.bitwarden-cli}/bin/bw get password "$item_id" 2>/dev/null | tr -d '\n')
            ;;
          username)
            value=$(${pkgs.bitwarden-cli}/bin/bw get item "$item_id" 2>/dev/null | ${pkgs.jq}/bin/jq -r '.login.username // empty' 2>/dev/null)
            ;;
          uri)
            value=$(${pkgs.bitwarden-cli}/bin/bw get item "$item_id" 2>/dev/null | ${pkgs.jq}/bin/jq -r '.login.uris[0].uri // empty' 2>/dev/null)
            ;;
          notes)
            value=$(${pkgs.bitwarden-cli}/bin/bw get item "$item_id" 2>/dev/null | ${pkgs.jq}/bin/jq -r '.notes // empty' 2>/dev/null)
            ;;
          totp)
            value=$(${pkgs.bitwarden-cli}/bin/bw get totp "$item_id" 2>/dev/null)
            ;;
          *)
            echo "Error: Unknown field '$field'" >&2
            return 1
            ;;
        esac

        if [ -z "$value" ]; then
          echo "Error: No $label found for item" >&2
          return 1
        fi

        bw-clipboard "$value" "${toString cfg.clipboardTimeout}" "$label"
      }
    '';
  };
}
