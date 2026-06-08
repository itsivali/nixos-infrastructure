{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.gitlabRunner;

  # -----------------------------
  # Fleet reconciliation script
  # -----------------------------
  reconcile = pkgs.writeShellApplication {
    name = "gitlab-runner-reconcile";

    runtimeInputs = [
      pkgs.gitlab-runner
      pkgs.curl
      pkgs.jq
      pkgs.systemd
    ];

    text = ''
      set -euo pipefail

      echo "[fleet] reconciling GitLab runner state..."

      # Ensure service is running
      systemctl is-active --quiet gitlab-runner.service || {
        echo "[fleet] runner down → restarting"
        systemctl restart gitlab-runner.service
      }

      # Verify registration (non-destructive)
      gitlab-runner list 2>/dev/null || true

      # Optional: cleanup stale runners (safe mode)
      gitlab-runner verify --delete || true

      echo "[fleet] reconciliation complete"
    '';
  };

  # -----------------------------
  # Health validation (pure)
  # -----------------------------
  health = pkgs.writeShellApplication {
    name = "gitlab-runner-health";

    runtimeInputs = [ pkgs.gitlab-runner pkgs.systemd ];

    text = ''
      set -euo pipefail

      systemctl is-active --quiet gitlab-runner.service

      # Lightweight sanity check only
      gitlab-runner --version >/dev/null
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

    # -----------------------------
    # GitLab Runner (fleet mode)
    # -----------------------------
    services.gitlab-runner = {
      enable = true;

      concurrency = cfg.concurrent;

      services.nix-shell = {
        executor = "shell";

        authenticationTokenConfigFile = cfg.tokenFile;

        tagList = cfg.tags;

        environmentVariables = {
          NIX_CONFIG = "experimental-features = nix-command flakes";
        };
      };
    };

    # -----------------------------
    # Fleet reconciliation timer
    # -----------------------------
    systemd.services.gitlab-runner-reconcile = {
      description = "GitLab Runner Fleet Reconciler";

      after = [
        "gitlab-runner.service"
        "network-online.target"
      ];

      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
      };

      script = "${reconcile}/bin/gitlab-runner-reconcile";
    };

    systemd.timers.gitlab-runner-reconcile = {
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnBootSec = "5m";
        OnUnitActiveSec = "10m";
        Persistent = true;
      };
    };

    # -----------------------------
    # Lightweight health gate
    # -----------------------------
    systemd.services.gitlab-runner-health = {
      description = "Fleet health gate";

      after = [ "gitlab-runner.service" ];

      serviceConfig = {
        Type = "oneshot";
      };

      script = "${health}/bin/gitlab-runner-health";

      # instead of rollback → just reconcile
      onFailure = [ "gitlab-runner-reconcile.service" ];
    };

    systemd.timers.gitlab-runner-health = {
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnBootSec = "10m";
        OnUnitActiveSec = "15m";
        Persistent = true;
      };
    };
  };
}
