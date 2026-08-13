##############################################################################
#
# Recovery Deployment Health
#
# Purpose
# -------
# Periodically validates whether the node is healthy for GitOps operations
# (GitLab Runner, reconciliation, rollback). Acts as a read-only observer
# that triggers rollback-on-failure when critical services are down.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Run the deployment-health.sh script every 5 minutes (default)
# - Provide systemd service and timer for health checking
# - Export GitOps context (repo, branch, worktree) to the health script
# - Trigger rollback-on-failure.service on health check failure
# - Enforce strict hardening (NoNewPrivileges, PrivateTmp, ProtectSystem=strict)
#
##############################################################################

# =============================================================================
# Fleet Deployment Health Monitor
# =============================================================================
#
# This module validates whether a node is safe to participate in GitOps
# operations (GitLab Runner, reconciliation, rollback decisions).
#
# It is a READ-ONLY observer.
#
# If it fails (a critical service is down) → rollback-on-failure.service is
# triggered, which re-checks in observer mode (STRICT_HEALTH=false, so a
# transient network blip does not roll back) and rolls back only on a genuine
# service regression.
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

        # nix needs a writable $HOME (its flake cache lives in ~/.cache/nix).
        # ProtectHome + ProtectSystem=strict make /root and /var/lib read-only,
        # so point it at the dedicated state dir (StateDirectory + ReadWritePaths).
        HOME = "/var/lib/deployment-health";

        # Periodic observer: connectivity blips must NOT trip the FAIL/rollback
        # path. Critical-service-down still FAILs and triggers rollback-on-failure.
        STRICT_HEALTH = "false";
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

        # Persistent writable $HOME for nix (see environment.HOME).
        StateDirectory = "deployment-health";

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

        # nix flake evaluation needs to write its cache under $HOME
        # (/var/lib/deployment-health), which ProtectSystem=strict would
        # otherwise mount read-only.
        ReadWritePaths = [
          "/var/lib/deployment-health"
        ];

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
      ## FAILURE → ROLLBACK-ON-FAILURE
      ######################################################################

      onFailure = [
        "rollback-on-failure.service"
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
