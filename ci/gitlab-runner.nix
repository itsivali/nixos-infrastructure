#
# ci/gitlab-runner.nix
#
# =============================================================================
# Fleet GitLab Runner
# =============================================================================
#
# Production GitLab Runner module for GitOps-managed NixOS.
#
# Responsibilities
#
#   • Configure GitLab Runner
#   • Schedule health monitoring
#   • Schedule reconciliation
#   • Export GitOps configuration
#   • Harden systemd services
#
# Git repository information is intentionally NOT configured here.
#
# Instead it is consumed from:
#
#   config.fleet.gitops.repo
#   config.fleet.gitops.branch
#
# defined by:
#
#   automation/options.nix
#   automation/common.nix
#
# =============================================================================

{ config, lib, pkgs, ... }:

let

  cfg = config.fleet.gitlabRunner;

  gitops = config.fleet.gitops;

  healthScript =
    if builtins.pathExists ../scripts/gitlab-runner-health.sh then
      ../scripts/gitlab-runner-health.sh
    else
      throw ''
        Missing:

          scripts/gitlab-runner-health.sh
      '';

  reconcileScript =
    if builtins.pathExists ../scripts/gitlab-runner-reconcile.sh then
      ../scripts/gitlab-runner-reconcile.sh
    else
      throw ''
        Missing:

          scripts/gitlab-runner-reconcile.sh
      '';

in

{

  ##############################################################################
  ## Options
  ##############################################################################

  options.fleet.gitlabRunner = {

    enable =
      lib.mkEnableOption "Fleet GitLab Runner";

    ##########################################################################
    ## Runner
    ##########################################################################

    executor = lib.mkOption {

      type = lib.types.enum [

        "shell"

        "docker"

        "docker+machine"

        "kubernetes"

      ];

      default = "shell";

    };

    tokenFile = lib.mkOption {

      type = lib.types.path;

      default =
        "/run/secrets/gitlab-runner-token";

    };

    concurrent = lib.mkOption {

      type = lib.types.int;

      default = 2;

    };

    tags = lib.mkOption {

      type = lib.types.listOf lib.types.str;

      default = [

        "nixos"

        "gitops"

        "fleet"

        "flakes"

      ];

    };

    ##########################################################################
    ## Timers
    ##########################################################################

    healthInterval = lib.mkOption {

      type = lib.types.str;

      default = "10m";

    };

    reconcileInterval = lib.mkOption {

      type = lib.types.str;

      default = "15m";

    };

    randomizedDelay = lib.mkOption {

      type = lib.types.str;

      default = "30s";

    };

  };

  ##############################################################################
  ## Configuration
  ##############################################################################

  config = lib.mkIf cfg.enable {

    ##############################################################################
    ## Secrets
    ##############################################################################

    sops.secrets.gitlab-runner-token = { };

    ##############################################################################
    ## GitLab Runner
    ##############################################################################

    services.gitlab-runner = {

      enable = true;

      concurrent = cfg.concurrent;

      services.default = {

        executor = cfg.executor;

        authenticationTokenConfigFile =
          cfg.tokenFile;

        tagList = cfg.tags;

        environmentVariables = {

          NIX_CONFIG =
            "experimental-features = nix-command flakes";

        };

      };

    };

    ##############################################################################
    ## Health Service
    ##############################################################################

    systemd.services.gitlab-runner-health = {

      description =
        "Fleet GitLab Runner Health";

      wants = [

        "network-online.target"

      ];

      after = [

        "gitlab-runner.service"

        "network-online.target"

      ];

      ##########################################################################
      ## Runtime packages
      ##########################################################################

      path = with pkgs; [

        bash

        git

        gitlab-runner

        nix

        curl

        jq

        coreutils

        gnugrep

        gnused

        gawk

        findutils

        systemd

      ];

      ##########################################################################
      ## Export GitOps configuration
      ##########################################################################

      environment = {

        ########################################################################
        ## GitOps
        ########################################################################

        GITOPS_REPO =
          gitops.repo;

        GITOPS_BRANCH =
          gitops.branch;

        ########################################################################
        ## Host
        ########################################################################

        HOST_NAME =
          config.networking.hostName;

        ########################################################################
        ## Repository location
        ########################################################################

        GITOPS_WORKTREE =
          "/var/lib/gitops";

      };

      ##########################################################################
      ## Service
      ##########################################################################

      serviceConfig = {

        Type = "oneshot";

        User = "root";

        Group = "root";

        ExecStart =
          healthScript;

        TimeoutStartSec = "120s";

        StandardOutput = "journal";

        StandardError = "journal";

        SyslogIdentifier =
          "gitlab-runner-health";

        ########################################################################
        ## Hardening
        ########################################################################

        NoNewPrivileges = true;

        PrivateTmp = true;

        PrivateDevices = true;

        ProtectHome = true;

        ProtectHostname = true;

        ProtectControlGroups = true;

        ProtectKernelLogs = true;

        ProtectKernelModules = true;

        ProtectKernelTunables = true;

        ProtectSystem = "strict";

        ProtectProc = "invisible";

        ProcSubset = "pid";

        LockPersonality = true;

        MemoryDenyWriteExecute = true;

        RestrictNamespaces = true;

        RestrictRealtime = true;

        RestrictSUIDSGID = true;

        UMask = "0077";

      };

      ##########################################################################
      ## Failed health → reconcile
      ##########################################################################

      onFailure = [

        "gitlab-runner-reconcile.service"

      ];

    };

    ##############################################################################
    ## Health Timer
    ##############################################################################

    systemd.timers.gitlab-runner-health = {

      description =
        "Periodic GitLab Runner Health";

      wantedBy = [

        "timers.target"

      ];

      timerConfig = {

        Unit =
          "gitlab-runner-health.service";

        OnBootSec = "5m";

        OnUnitActiveSec =
          cfg.healthInterval;

        RandomizedDelaySec =
          cfg.randomizedDelay;

        AccuracySec = "1min";

        Persistent = true;

      };

    };

    ##############################################################################
    ## Reconciliation Service
    ##############################################################################

    systemd.services.gitlab-runner-reconcile = {

      description =
        "Fleet GitLab Runner Reconciliation";

      wants = [

        "network-online.target"

      ];

      after = [

        "network-online.target"

      ];

      path = with pkgs; [

        bash

        git

        gitlab-runner

        nix

        curl

        jq

        coreutils

        gnugrep

        gnused

        gawk

        systemd

      ];

      environment = {

        GITOPS_REPO =
          gitops.repo;

        GITOPS_BRANCH =
          gitops.branch;

        HOST_NAME =
          config.networking.hostName;

        GITOPS_WORKTREE =
          "/var/lib/gitops";

      };

      serviceConfig = {

        Type = "oneshot";

        User = "root";

        Group = "root";

        ExecStart =
          reconcileScript;

        TimeoutStartSec = "120s";

        StandardOutput = "journal";

        StandardError = "journal";

        SyslogIdentifier =
          "gitlab-runner-reconcile";

      };

    };

    ##############################################################################
    ## Reconciliation Timer
    ##############################################################################

    systemd.timers.gitlab-runner-reconcile = {

      description =
        "Periodic GitLab Runner Reconciliation";

      wantedBy = [

        "timers.target"

      ];

      timerConfig = {

        Unit =
          "gitlab-runner-reconcile.service";

        OnBootSec = "10m";

        OnUnitActiveSec =
          cfg.reconcileInterval;

        RandomizedDelaySec =
          cfg.randomizedDelay;

        AccuracySec = "1min";

        Persistent = true;

      };

    };

  };

}
