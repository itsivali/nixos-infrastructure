##############################################################################
#
# Bitwarden Integration
#
# Purpose
# -------
# First-class Bitwarden subsystem for NixOS infrastructure.
# Provides authentication, clipboard, cache, search, and helper commands.
#
# Ownership
# ---------
# options.ivali.bitwarden
#
# Responsibilities
# ----------------
# - env.nix       — Authentication, session management, SOPS credentials
# - clipboard.nix — Clipboard abstraction (wl-copy/xclip) + auto-clear
# - cache.nix     — Vault item cache, favorites, recent entries
# - search.nix    — fzf/rofi/wofi search, action menu, helper commands
# - completion.nix — Shell completions (Zsh, Bash, Fish)
#
# Does NOT Own
# ------------
# - Shell aliases (home/shell/aliases/bitwarden.nix)
# - SOPS secrets (lib/host-templates/laptop.nix)
#
##############################################################################

{ config, pkgs, lib, ... }:

let
  cfg = config.ivali.bitwarden;
in
{
  imports = [
    ./env.nix
    ./clipboard.nix
    ./cache.nix
    ./search.nix
    ./completion.nix
  ];

  options.ivali.bitwarden = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Bitwarden CLI integration.";
    };

    clipboardTimeout = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "Seconds before clipboard is automatically cleared.";
    };

    enableNotifications = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable desktop notifications for clipboard and vault events.";
    };

    searchTool = lib.mkOption {
      type = lib.types.enum [ "auto" "fzf" "rofi" "wofi" ];
      default = "auto";
      description = "Search tool for interactive selection. 'auto' probes rofi then wofi then fzf.";
    };

    enableAliases = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Register shell aliases (bws, bwu, bwl, etc.).";
    };

    enableTotp = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable TOTP support (requires Bitwarden Premium).";
    };

    enableFavorites = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable favorite vault entries (pinned at top of search).";
    };

    enableRecent = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable recent vault entries (last 10 accessed).";
    };

    autoSync = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically sync vault on unlock.";
    };

    autoUnlock = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Automatically unlock vault at shell startup using SOPS credentials.";
    };

    inactivityTimeout = lib.mkOption {
      type = lib.types.int;
      default = 300;
      description = "Seconds of inactivity before auto-locking vault.";
    };

    cacheTtl = lib.mkOption {
      type = lib.types.int;
      default = 300;
      description = "Vault item cache lifetime in seconds.";
    };

    sops = {
      clientId = lib.mkOption {
        type = lib.types.path;
        default = "/run/secrets/bitwarden_clientid";
        description = "Path to SOPS-decrypted Bitwarden client ID.";
      };

      clientSecret = lib.mkOption {
        type = lib.types.path;
        default = "/run/secrets/bitwarden_clientsecret";
        description = "Path to SOPS-decrypted Bitwarden client secret.";
      };

      password = lib.mkOption {
        type = lib.types.path;
        default = "/run/secrets/bitwarden_password";
        description = "Path to SOPS-decrypted Bitwarden master password.";
      };

      server = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to SOPS-decrypted Bitwarden server URL (optional).";
      };

      email = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to SOPS-decrypted Bitwarden email (optional).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      bitwarden-cli
      jq
      fzf
      wl-clipboard
      xclip
      libsecret
      libnotify
    ];

    home.sessionVariables = {
      BW_SESSION_DIR = "/run/user/1000/bitwarden";
    };

    programs.zsh.shellAliases = lib.mkIf cfg.enableAliases {
      bws   = "bwstatus";
      bwu   = "bwunlock";
      bwl   = "bwlock";
      bwc   = "bwclear";
      bwsy  = "bwsync";
      bwlo  = "bwlogout";
      bwf   = "bwfind";
    };

    programs.zsh.initContent = lib.mkAfter ''
      # Ensure runtime directory exists
      BW_RT_DIR="''${XDG_RUNTIME_DIR:-/run/user/$UID}/bitwarden"
      [ -d "$BW_RT_DIR" ] || mkdir -p "$BW_RT_DIR"

      # Bitwarden notification wrapper
      bw-notify() {
        ${lib.optionalString cfg.enableNotifications ''notify-send "Bitwarden" "$1" 2>/dev/null''}
      }
    '';
  };
}
