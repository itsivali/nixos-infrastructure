##############################################################################
#
# GitLab Host Token — self-rotation
#
# Purpose
# -------
# Rotates the dedicated host GitLab personal access token before it expires,
# so the GitLab runner and GitOps automation never depend on an expired
# token. Rotates when <= fleet.gitlabTokenRotate.dropDaysBefore days remain,
# sets a new expiry of newTtlDays, re-encrypts secrets/gitlab.yaml in a
# dedicated worktree, pushes the new token to the GitOps branch, then
# triggers the GitOps reconciler to re-materialise the secret.
#
# Ownership
# ---------
# fleet.gitlabTokenRotate.*, systemd gitlab-token-rotate.{service,timer}
#
# Dependencies
# ------------
# - SOPS secret: secrets/gitlab.yaml -> gitlab_token (the host token).
# - The token must carry the `api` (or `self_rotate`) scope.
# - The operator's passphrase-less SSH deploy key (same as the reconciler).
#
# This token is the *host* token and is intentionally distinct from the
# operator's glab CLI token so rotation never breaks interactive tooling.
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.fleet.gitlabTokenRotate;
  gitops = config.fleet.gitops;

  rotateScript =
    if builtins.pathExists ../scripts/gitlab-token-rotate.sh then
      ../scripts/gitlab-token-rotate.sh
    else
      throw ''
        Missing script:

          scripts/gitlab-token-rotate.sh
      '';
in
{
  options.fleet.gitlabTokenRotate = {
    enable = lib.mkEnableOption "Self-rotation of the host GitLab token";

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      example = "Mon *-*-* 06:00:00";
      description = "systemd OnCalendar schedule for the rotation check.";
    };

    dropDaysBefore = lib.mkOption {
      type = lib.types.int;
      default = 7;
      description = ''
        Rotate once the token has this many days or fewer until expiry.
      '';
    };

    newTtlDays = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "Lifetime in days requested for the rotated token.";
    };
  };

  config = lib.mkIf cfg.enable {

    # The service runs as the operator (ivali) so it can use the operator's
    # deploy key and the age private key; make the host token readable to it.
    # (root, as the GitLab runner health service, can still read it.)
    sops.secrets.gitlab_token = {
      sopsFile = ../secrets/gitlab.yaml;
      owner = "ivali";
      mode = "0400";
    };

    systemd.services.gitlab-token-rotate = {
      description = "Rotate the host GitLab token before expiry";

      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      environment = {
        GITLAB_API_BASE = "https://gitlab.com/api/v4";
        GITLAB_TOKEN_FILE = config.sops.secrets.gitlab_token.path;

        GITLAB_REPO = gitops.repo;
        GITLAB_BRANCH = gitops.branch;

        SOPS_AGE_KEY_FILE = config.sops.age.keyFile;

        DROP_DAYS_BEFORE = builtins.toString cfg.dropDaysBefore;
        NEW_TTL_DAYS = builtins.toString cfg.newTtlDays;

        # Reuse the operator's passphrase-less deploy key, like the reconciler.
        GIT_SSH_COMMAND = "ssh -i /home/ivali/.ssh/id_ed25519 -o UserKnownHostsFile=/home/ivali/.ssh/known_hosts -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes";
      };

      path = with pkgs; [
        bash
        coreutils
        curl
        jq
        git
        sops
        age
        gnugrep
        gnused
        gawk
        findutils
        openssh
        sudo
        systemd
        util-linux
        inetutils
        msmtp
      ];

      serviceConfig = {
        Type = "oneshot";
        User = "ivali";

        # Dedicated worktree — never the operator's checkout, and never the
        # reconciler's /var/lib/gitops (committing there would make the
        # reconciler consider itself up to date and skip the deploy).
        StateDirectory = "gitlab-token-rotate";

        TimeoutStartSec = "300s";

        StandardOutput = "journal";
        StandardError = "journal";
        SyslogIdentifier = "gitlab-token-rotate";

        NoNewPrivileges = true;
        PrivateTmp = true;
        LockPersonality = true;
        UMask = "0077";
      };
    };

    systemd.timers.gitlab-token-rotate = {
      description = "Periodic host GitLab token rotation check";

      wantedBy = [ "timers.target" ];

      timerConfig = {
        Unit = "gitlab-token-rotate.service";
        OnCalendar = cfg.schedule;
        RandomizedDelaySec = "1h";
        AccuracySec = "5min";
        Persistent = true;
      };
    };
  };
}
