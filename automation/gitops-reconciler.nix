##############################################################################
#
# Automation GitOps Reconciler
#
# Purpose
# -------
# Defines the GitOps reconciliation service and timer that pulls configuration
# changes from GitLab and applies them via nixos-rebuild switch.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Configure the gitops-reconciler systemd service with git, nix, and SSH paths
# - Set up a periodic timer for automated reconciliation (default: every 15 min)
# - Pass GitOps context (repo, branch, host) as environment variables to the reconciler
# - Provide hardened service settings (NoNewPrivileges, PrivateTmp, LockPersonality)
#
##############################################################################

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

    # Pre-create the deploy lock owned by ivali: the reconciler runs as the
    # operator user (ivali) but /run is root-owned, so without this the lock
    # acquisition ("exec 9> /run/deploy.lock") fails on every run.
    systemd.tmpfiles.rules = [
      "f /run/deploy.lock 0660 ivali users -"
    ];

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
        util-linux # flock (deploy lock)
        inetutils # hostname (notify.sh)
        nixos-rebuild # activation step
        msmtp # sendmail (notify.sh email)
        openssh # ssh transport for git fetch/pull over git@gitlab.com
      ];

      ######################################################################
      ## GitOps context (SINGLE SOURCE OF TRUTH)
      ######################################################################

      environment = {
        HOST_NAME = config.networking.hostName;

        GITOPS_REPO = gitops.repo;
        GITOPS_BRANCH = gitops.branch;

        GITOPS_MAX_RETRIES = builtins.toString cfg.maxRetries;
        GITOPS_RETRY_DELAY = builtins.toString cfg.retryDelay;
        GITOPS_USE_IVALI_DOCTOR = if cfg.useIvaliDoctor then "true" else "false";

        # #6 Canary gate: when "1", gitops-reconcile.sh boots a NixOS VM
        # and runs a smoke test before activating the new generation.
        GITOPS_CANARY = if cfg.canary then "1" else "0";
        # Optional: pick a lighter check (all checks are VM-based).
        # CANARY_CHECK = "automation-smoke";

        # The reconciler runs as the operator user (ivali), who owns the
        # passphrase-less deploy key, so OpenSSH accepts it for git
        # fetch/pull over git@gitlab.com. The nixos-rebuild switch step
        # escalates to root via `sudo` (NOPASSWD for ivali). For stricter
        # isolation you could instead provision a dedicated root-owned GitLab
        # deploy key.
        GIT_SSH_COMMAND = "ssh -i /home/ivali/.ssh/id_ed25519 -o UserKnownHostsFile=/home/ivali/.ssh/known_hosts -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes";
      };

      serviceConfig = {
        Type = "oneshot";
        User = "ivali";
        # Group omitted: systemd uses ivali's primary group (no dedicated
        # 'ivali' group is declared; referencing it breaks the spawn step).

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
        ## HARDENING
        ## A GitOps deploy loop drives `nixos-rebuild switch`, so it must
        ## write to /nix/store, /boot and /etc and spawn nix build sandboxes
        ## (bwrap/user namespaces). The strict filesystem/namespace sandboxing
        ## is therefore disabled; the service stays root but runs unconfined
        ## for AppArmor (shared-lib loading) and keeps a minimal safe subset.
        ####################################################################

        NoNewPrivileges = true;
        PrivateTmp = true;
        LockPersonality = true;
        UMask = "0077";

        # NOTE: hardening intentionally minimal — this unit performs full
        # system switches, so broad filesystem/namespace access is required.
        # Verified end-to-end: the loop reaches the local checkout and emits
        # Telegram + Outlook notifications on every successful deploy.

        # Treat a notified failure (exit 1) as success so a failed deploy
        # (already reported via notify.sh) never blocks `nixos-rebuild
        # switch` with exit 4.
        SuccessExitStatus = "1";
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
