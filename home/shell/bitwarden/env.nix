##############################################################################
#
# Bitwarden Environment & Authentication
#
# Purpose
# -------
# Session management, credential sourcing, and vault authentication.
# Credentials are read from SOPS-decrypted files in /run/secrets/.
# Session is stored in $XDG_RUNTIME_DIR/bitwarden/session (tmpfs, RAM-only).
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
      # Bitwarden Session Management
      # ═══════════════════════════════════════════════════════════════════════

      bw_ensure_rt_dir() {
        [ -d "$BW_RT_DIR" ] || mkdir -p "$BW_RT_DIR"
      }

      bw_update_activity() {
        echo "$(date +%s)" > "$BW_ACTIVITY_FILE" 2>/dev/null
      }

      bw_get_activity_age() {
        if [ -f "$BW_ACTIVITY_FILE" ]; then
          local last
          last=$(<"$BW_ACTIVITY_FILE")
          local now
          now=$(date +%s)
          echo $((now - last))
        else
          echo 0
        fi
      }

      # ═══════════════════════════════════════════════════════════════════════
      # Core Authentication Functions
      # ═══════════════════════════════════════════════════════════════════════

      bwunlock() {
        bw_ensure_rt_dir

        # Check if already unlocked
        if [ -n "$BW_SESSION" ]; then
          local check_status
          check_status=$(echo "$BW_SESSION" | ${pkgs.bitwarden-cli}/bin/bw status 2>/dev/null | ${pkgs.jq}/bin/jq -r '.status' 2>/dev/null || echo "unknown")
          if [ "$check_status" = "unlocked" ]; then
            echo "Vault already unlocked."
            bw_update_activity
            return 0
          fi
        fi

        # Read credentials from SOPS
        local clientId="" clientSecret="" password=""
        [ -f "${cfg.sops.clientId}" ] && clientId=$(<"${cfg.sops.clientId}")
        [ -f "${cfg.sops.clientSecret}" ] && clientSecret=$(<"${cfg.sops.clientSecret}")
        [ -f "${cfg.sops.password}" ] && password=$(<"${cfg.sops.password}")

        ${lib.optionalString (cfg.sops.server != null) ''
          [ -f "${cfg.sops.server}" ] && export BW_SERVERURL=$(<"${cfg.sops.server}")
        ''}

        if [ -z "$clientId" ] || [ -z "$clientSecret" ]; then
          echo "Error: SOPS credentials not found at ${cfg.sops.clientId}" >&2
          echo "Run: sudo nixos-rebuild switch" >&2
          return 1
        fi

        # Export API credentials
        export BW_CLIENTID="$clientId"
        export BW_CLIENTSECRET="$clientSecret"

        # Check current login status
        local bw_status
        bw_status=$(${pkgs.bitwarden-cli}/bin/bw status 2>/dev/null | ${pkgs.jq}/bin/jq -r '.status' 2>/dev/null || echo "unknown")

        case "$bw_status" in
          "unlocked")
            if [ -f "$BW_SESSION_FILE" ]; then
              export BW_SESSION=$(<"$BW_SESSION_FILE")
              bw_update_activity
              echo "Vault already unlocked."
              return 0
            fi
            ;;
           "unauthenticated")
            ${pkgs.bitwarden-cli}/bin/bw login --apikey > /dev/null 2>&1 || true
            ;;
          "locked")
            # Already logged in, just need to unlock
            ;;
          "error")
            echo "Error: Cannot connect to Bitwarden server" >&2
            return 1
            ;;
        esac

        # Unlock vault
        local session
        if [ -n "$password" ]; then
          session=$(BW_PASSWORD="$password" ${pkgs.bitwarden-cli}/bin/bw unlock --passwordenv BW_PASSWORD --raw 2>/dev/null)
        else
          echo "Unlocking vault..."
          session=$(${pkgs.bitwarden-cli}/bin/bw unlock --raw 2>/dev/null)
        fi

        # Clear password from env immediately
        unset BW_PASSWORD

        if [ -z "$session" ]; then
          echo "Error: Failed to unlock vault" >&2
          return 1
        fi

        export BW_SESSION="$session"
        printf '%s' "$session" > "$BW_SESSION_FILE"
        chmod 600 "$BW_SESSION_FILE"
        bw_update_activity

        ${lib.optionalString cfg.autoSync ''
          ${pkgs.bitwarden-cli}/bin/bw sync > /dev/null 2>&1 || true
          [ -f "$BW_RT_DIR/cache.json" ] && rm -f "$BW_RT_DIR/cache.json"
        ''}

        bw-notify "Vault unlocked"
        echo "Vault unlocked."
      }

      bwlock() {
        ${pkgs.bitwarden-cli}/bin/bw lock > /dev/null 2>&1 || true
        unset BW_SESSION 2>/dev/null || true
        bw_ensure_rt_dir
        rm -f "$BW_SESSION_FILE"
        bw-notify "Vault locked"
        echo "Vault locked."
      }

      bwlogout() {
        ${pkgs.bitwarden-cli}/bin/bw logout > /dev/null 2>&1 || true
        unset BW_SESSION 2>/dev/null || true
        bw_ensure_rt_dir
        rm -f "$BW_SESSION_FILE"
        rm -f "$BW_RT_DIR/cache.json" 2>/dev/null
        rm -f "$BW_RT_DIR/recent" 2>/dev/null
        bw-notify "Logged out"
        echo "Logged out."
      }

      bwstatus() {
        ${pkgs.bitwarden-cli}/bin/bw status 2>/dev/null | ${pkgs.jq}/bin/jq '.' 2>/dev/null || echo "Status: unknown"
      }

      bwsync() {
        if [ -f "$BW_SESSION_FILE" ]; then
          export BW_SESSION="''${BW_SESSION:-$(<"$BW_SESSION_FILE")}"
        fi

        if [ -z "$BW_SESSION" ]; then
          echo "Error: Vault is locked. Run: bwunlock" >&2
          return 1
        fi

        ${pkgs.bitwarden-cli}/bin/bw sync 2>/dev/null

        # Invalidate cache
        [ -f "$BW_RT_DIR/cache.json" ] && rm -f "$BW_RT_DIR/cache.json"

        bw_update_activity
        bw-notify "Vault synced"
        echo "Vault synced."
      }

      bwclear() {
        unset BW_SESSION 2>/dev/null || true
        echo "Session cleared."
      }

      # ═══════════════════════════════════════════════════════════════════════
      # Auto-Unlock Hook (shell startup)
      # ═══════════════════════════════════════════════════════════════════════

      ${lib.optionalString cfg.autoUnlock ''
        if [[ -z "$BW_SESSION" ]] && [[ -f "$BW_SESSION_FILE" ]]; then
          export BW_SESSION=$(<"$BW_SESSION_FILE")
        fi
        if [[ -z "$BW_SESSION" ]]; then
          bwunlock 2>/dev/null || true
        fi
      ''}

      # ═══════════════════════════════════════════════════════════════════════
      # Inactivity Auto-Lock
      # ═══════════════════════════════════════════════════════════════════════

      _bw_precmd_hook() {
        if [ -n "$BW_SESSION" ] && [ ${toString cfg.inactivityTimeout} -gt 0 ]; then
          local age
          age=$(bw_get_activity_age)
          if [ "$age" -ge ${toString cfg.inactivityTimeout} ]; then
            bwlock 2>/dev/null
          fi
        fi
      }

      if [ -n "$ZSH_VERSION" ]; then
        autoload -Uz add-zsh-hook
        add-zsh-hook precmd _bw_precmd_hook
      fi

      # ═══════════════════════════════════════════════════════════════════════
      # Runtime Initialization
      # ═══════════════════════════════════════════════════════════════════════

      ${lib.optionalString (!cfg.autoUnlock) ''
        if [[ -f "$BW_SESSION_FILE" ]] && [[ -z "$BW_SESSION" ]]; then
          export BW_SESSION=$(<"$BW_SESSION_FILE")
        fi
      ''}
    '';
  };
}
