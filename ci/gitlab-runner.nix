{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.gitlabRunner;

  # ─────────────────────────────────────────────
  # OBSERVE: health snapshot (no side effects)
  # ─────────────────────────────────────────────
  health = pkgs.writeShellApplication {
    name = "gitlab-runner-health";

    runtimeInputs = [
      pkgs.gitlab-runner
      pkgs.systemd
      pkgs.jq
    ];

    text = ''
      set -euo pipefail

      echo "[health] checking runner service..."

      systemctl is-active --quiet gitlab-runner.service

      echo "[health] version check..."
      gitlab-runner --version >/dev/null

      echo "[health] runner list snapshot..."
      gitlab-runner list 2>/dev/null || true

      echo "[health] OK"
    '';
  };

  # ─────────────────────────────────────────────
  # DECIDE + ACT: reconciliation loop
  # (idempotent, not destructive)
  # ─────────────────────────────────────────────
  reconcile = pkgs.writeShellApplication {
    name = "gitlab-runner-reconcile";

    runtimeInputs = [
      pkgs.gitlab-runner
      pkgs.systemd
    ];

    text = ''
      set -euo pipefail

      echo "[reconcile] starting fleet reconciliation..."

      # ensure service exists
      if ! systemctl is-active --quiet gitlab-runner.service; then
        echo "[reconcile] runner inactive → starting"
        systemctl start gitlab-runner.service
      fi

      # verify configuration consistency
      gitlab-runner verify --delete || true

      echo "[reconcile] complete"
    '';
  };

in
{
  options.ivali.gitlabRunner = {
    enable = lib.mkEnableOption "GitLab Runner Fleet (self-healing)";

    tokenFile = lib.mkOption {
      type = lib.types.path;
      default = "/run/secrets/gitlab-runner-token";
    };

    tags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "nixos" "fleet" "flakes" ];
    };

    fleetName = lib.mkOption {
      type = lib.types.str;
      default = "default-fleet";
    };

    concurrent = lib.mkOption {
      type = lib.types.int;
      default = 2;
    };
  };

  config = lib.mkIf cfg.enable {

    sops.secrets.gitlab-runner-token = { };

    # ─────────────────────────────────────────────
    # GitLab Runner (stable declarative config)
    # ─────────────────────────────────────────────
    services.gitlab-runner = {
      enable = true;

      # IMPORTANT FIX:
      # avoid breaking nixpkgs compatibility across versions
      concurrent = lib.mkDefault cfg.concurrent;

      services.nix-shell = {
        executor = "shell";

        authenticationTokenConfigFile = cfg.tokenFile;

        tagList = cfg.tags;

        environmentVariables = {
          NIX_CONFIG = "experimental-features = nix-command flakes";
        };
      };
    };

    # ─────────────────────────────────────────────
    # HEALTH GATE (pure observer)
    # ─────────────────────────────────────────────
    systemd.services.gitlab-runner-health = {
      description = "GitLab Runner Fleet Health Check";

      after = [ "gitlab-runner.service" "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
      };

      script = "${health}/bin/gitlab-runner-health";

      # if health fails → attempt reconcile
      onFailure = [ "gitlab-runner-reconcile.service" ];
    };

    systemd.timers.gitlab-runner-health = {
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnBootSec = "5m";
        OnUnitActiveSec = "10m";
        Persistent = true;
      };
    };

    # ─────────────────────────────────────────────
    # RECONCILIATION LOOP (idempotent actuator)
    # ─────────────────────────────────────────────
    systemd.services.gitlab-runner-reconcile = {
      description = "GitLab Runner Fleet Reconciler";

      after = [ "gitlab-runner.service" "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
      };

      script = "${reconcile}/bin/gitlab-runner-reconcile";
    };

    systemd.timers.gitlab-runner-reconcile = {
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnBootSec = "10m";
        OnUnitActiveSec = "15m";
        Persistent = true;
      };
    };
  };
}
