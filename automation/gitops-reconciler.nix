#
# ==============================================================================
# Fleet GitOps Reconciler
# ==============================================================================
#
# This service is the ACTUATOR in the fleet control loop.
#
# It is triggered by:
#
#   • deployment-health.service (OnFailure)
#   • gitlab-runner-health.service (OnFailure)
#   • scheduled timer (periodic reconciliation)
#
# It performs system correction ONLY when required.
#
# ==============================================================================
#

{ config, lib, pkgs, ... }:

let
  cfg = config.fleet.gitopsReconciler;
  gitops = config.fleet.gitops;

  reconcileScript =
    if builtins.pathExists ../scripts/gitops-reconcile.sh then
      ../scripts/gitops-reconcile.sh
    else
      throw ''
        Missing script:

          scripts/gitops-reconcile.sh
      '';
in
{
  ##########################################################################
  ## OPTIONS
  ##########################################################################

  options.fleet.gitopsReconciler = {

    enable = lib.mkEnableOption "Fleet GitOps reconciler";

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "*:0/15";
      description = "systemd OnCalendar schedule";
    };

    randomizedDelay = lib.mkOption {
      type = lib.types.str;
      default = "45s";
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

    systemd.services.gitops-reconciler = {
      description = "Fleet GitOps Reconciliation Loop";

      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      path = with pkgs; [
        bash
        coreutils
        curl
        git
        nix
        jq
        gnugrep
        gnused
        gawk
        systemd
        findutils
      ];

      ######################################################################
      ## GitOps context (SINGLE SOURCE OF TRUTH)
      ######################################################################

      environment = {
        HOST_NAME = config.networking.hostName;

        GITOPS_REPO = gitops.repo;
        GITOPS_BRANCH = gitops.branch;

        GITOPS_WORKTREE = "/var/lib/gitops";

        GITOPS_MAX_RETRIES = builtins.toString cfg.maxRetries;
        GITOPS_RETRY_DELAY = builtins.toString cfg.retryDelay;
        GITOPS_USE_IVALI_DOCTOR = if cfg.useIvaliDoctor then "true" else "false";
      };

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        Group = "root";

        ExecStart = reconcileScript;

        TimeoutStartSec = "180s";

        StandardOutput = "journal";
        StandardError = "journal";

        SyslogIdentifier = "gitops-reconciler";

        # Run unconfined: the reconciler is a root service that drives
        # nixos-rebuild/git and must load shared libs (bash -> libreadline).
        # AppArmor's exec-mmap mediation for shared libraries is unreliable in
        # this environment and broke the reconciler (bash exited 127 on every
        # run), so the GitOps deploy loop was dead. The bot stays confined
        # (it is built as a static pure-Go binary, so it needs no libs).
        AppArmorProfile = "unconfined";

        ####################################################################
        ## HARDENING (slightly less strict than health checks)
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
    };

    ########################################################################
    ## TIMER (scheduled reconciliation loop)
    ########################################################################

    systemd.timers.gitops-reconciler = {
      description = "Fleet GitOps Reconciliation Timer";

      wantedBy = [ "timers.target" ];

      timerConfig = {
        Unit = "gitops-reconciler.service";

        OnCalendar = cfg.schedule;
        RandomizedDelaySec = cfg.randomizedDelay;
        AccuracySec = cfg.accuracy;

        Persistent = true;
      };
    };

  };
}
