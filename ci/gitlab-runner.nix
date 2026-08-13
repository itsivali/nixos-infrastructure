##############################################################################
#
# GitLab Runner
#
# Purpose
# -------
# Production GitLab Runner module for GitOps-managed NixOS.
#
# Ownership
# ---------
# services.gitlab-runner, associated systemd services/timers
#
# Responsibilities
# ----------------
# - Configure GitLab Runner
# - Schedule health monitoring
# - Schedule reconciliation
# - Export GitOps configuration
# - Harden systemd services
#
# Does NOT Own
# ------------
# - fleet.gitops options (automation/options.nix)
# - GitOps reconciler (automation/gitops-reconciler.nix)
#
##############################################################################

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

      default = "1h";

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

    sops.secrets.gitlab_token = {
      sopsFile = ../secrets/gitlab.yaml;
    };

    ##############################################################################
    ## GitLab Runner
    ##############################################################################

    services.gitlab-runner = {

      enable = true;

      settings.concurrent = cfg.concurrent;

      services.default = {

        executor = cfg.executor;

        authenticationTokenConfigFile =
          cfg.tokenFile;

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

        util-linux

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
        ## Private repository access (GitLab API token)
        ########################################################################

        GITLAB_TOKEN_FILE =
          config.sops.secrets.gitlab_token.path;

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

        util-linux

        inetutils

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

        ########################################################################
        ## Private repository access (GitLab API token)
        ########################################################################

        GITLAB_TOKEN_FILE =
          config.sops.secrets.gitlab_token.path;

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
