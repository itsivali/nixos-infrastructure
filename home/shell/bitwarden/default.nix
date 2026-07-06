##############################################################################
#
# Bitwarden Integration
#
# Purpose
# -------
# First-class Bitwarden subsystem for NixOS infrastructure.
# Provides authentication, session management, cache, and shell
# integration for the `bw` Go TUI binary.
#
# Ownership
# ---------
# options.ivali.bitwarden
#
# Responsibilities
# ----------------
# - env.nix       — Authentication, session management, SOPS credentials
# - cache.nix     — Vault item cache, favorites, recent entries
# - completion.nix — Shell completions (Zsh, Bash, Fish)
#
# The interactive TUI (bwfind, bw) lives in cmd/bw/ — a Go binary
# built with Bubble Tea. This module only handles shell-level setup.
#
##############################################################################

{ config, pkgs, lib, inputs, ... }:

let
  cfg = config.ivali.bitwarden;
in
{
  imports = [
    ./env.nix
    ./cache.nix
    ./completion.nix
  ];

  options.ivali.bitwarden = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Bitwarden integration.";
    };

    enableNotifications = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable desktop notifications for vault events.";
    };

    enableAliases = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Register shell aliases (bw, bwfind, etc.).";
    };

    enableFavorites = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable favorite vault entries.";
    };

    enableRecent = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable recent vault entries (last 10 accessed).";
    };

    autoUnlock = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Automatically unlock vault at shell startup using SOPS credentials.";
    };

    autoSync = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically sync vault on unlock.";
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
      wl-clipboard
      xclip
      libnotify
    ] ++ lib.optional (inputs ? self)
      inputs.self.packages.${pkgs.system}.bw;

    home.sessionVariables = {
      BW_SESSION_DIR = "${config.xdg.cacheHome}/bitwarden";
    };

    programs.zsh.shellAliases = lib.mkIf cfg.enableAliases {
      bwu   = "bw unlock";
      bwl   = "bw lock";
      bws   = "bw status";
      bwsy  = "bw sync";
      bwlo  = "bw logout";
      bwf   = "bwfind";
    };

    programs.zsh.initContent = lib.mkBefore ''
      # ═══════════════════════════════════════════════════════════════════════
      # Bitwarden — Runtime Directory (must be first)
      # ═══════════════════════════════════════════════════════════════════════
      BW_RT_DIR="''${XDG_RUNTIME_DIR:-/run/user/$UID}/bitwarden"
      BW_SESSION_FILE="$BW_RT_DIR/session"
      BW_ACTIVITY_FILE="$BW_RT_DIR/last-activity"
      [ -d "$BW_RT_DIR" ] || mkdir -p "$BW_RT_DIR"

      BW_CACHE_FILE="$BW_RT_DIR/cache.json"
      BW_CACHE_TIME="$BW_RT_DIR/cache-time"

      # Bitwarden notification wrapper
      bw-notify() {
        ${lib.optionalString cfg.enableNotifications ''notify-send "Bitwarden" "$1" 2>/dev/null''}
      }

      # bwfind — alias for the bw TUI with filter pre-populated
      bwfind() { bw "$@"; }
    '';
  };
}
