# =============================================================================
# Fleet Deployment Health Monitor
# =============================================================================
#
# This module validates whether a node is safe to participate in GitOps
# operations (GitLab Runner, reconciliation, rollback decisions).
#
# It is a READ-ONLY observer.
#
# If it fails → gitops-reconciler.service is triggered.
#
# =============================================================================

{ config, lib, pkgs, ... }:

let
  cfg = config.fleet.deploymentHealth;
  gitops = config.fleet.gitops;

  deploymentHealthScript =
    if builtins.pathExists ../scripts/deployment-health.sh then
      ../scripts/deployment-health.sh
    else
      throw ''
        deployment-health.sh not found at:

        scripts/deployment-health.sh
      '';
in
{
  ##########################################################################
  ## OPTIONS
  ##########################################################################

  options.fleet.deploymentHealth = {

    enable = lib.mkEnableOption "Fleet deployment health monitoring";

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "*:0/5";
      description = "systemd OnCalendar schedule";
    };

    randomizedDelay = lib.mkOption {
      type = lib.types.str;
      default = "30s";
    };

    accuracy = lib.mkOption {
      type = lib.types.str;
      default = "1min";
    };

  };

  ##########################################################################
  ## CONFIG
  ##########################################################################

  config = lib.mkIf cfg.enable {

    ########################################################################
    ## SERVICE
    ########################################################################

    systemd.services.deployment-health = {
      description = "Fleet Deployment Health Check";

      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      ######################################################################
      ## Runtime tools required for GitOps validation
      ######################################################################

      path = with pkgs; [
        bash
        coreutils
        curl
        gnugrep
        gnused
        gawk
        dnsutils
        iputils
        inetutils
        procps
        systemd
        util-linux

        # GitOps validation tools
        git
        nix
        findutils
      ];

      ######################################################################
      ## GitOps context exported to script
      ######################################################################

      environment = {
        HOST_NAME = config.networking.hostName;

        GITOPS_REPO = gitops.repo;
        GITOPS_BRANCH = gitops.branch;

        GITOPS_WORKTREE = "/var/lib/gitops";
      };

      ######################################################################
      ## SERVICE EXECUTION
      ######################################################################

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        Group = "root";

        ExecStart = deploymentHealthScript;

        TimeoutStartSec = "90s";

        Nice = 10;
        IOSchedulingClass = "idle";

        StandardOutput = "journal";
        StandardError = "journal";

        SyslogIdentifier = "deployment-health";

        ####################################################################
        ## HARDENING (observer-only safe mode)
        ####################################################################

        NoNewPrivileges = true;

        PrivateTmp = true;
        PrivateDevices = true;

        ProtectHome = true;
        ProtectHostname = true;

        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectControlGroups = true;

        ProtectProc = "invisible";
        ProcSubset = "pid";

        ProtectSystem = "strict";

        LockPersonality = true;
        MemoryDenyWriteExecute = true;

        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;

        RemoveIPC = true;

        SystemCallArchitectures = "native";

        UMask = "0077";
      };

      ######################################################################
      ## FAILURE → RECOVERY PIPELINE
      ######################################################################

      onFailure = [
        "gitops-reconciler.service"
      ];
    };

    ########################################################################
    ## TIMER
    ########################################################################

    systemd.timers.deployment-health = {
      description = "Run Deployment Health Check";

      wantedBy = [ "timers.target" ];

      timerConfig = {
        Unit = "deployment-health.service";

        OnCalendar = cfg.schedule;
        RandomizedDelaySec = cfg.randomizedDelay;
        AccuracySec = cfg.accuracy;

        Persistent = true;
      };
    };
  };
}
