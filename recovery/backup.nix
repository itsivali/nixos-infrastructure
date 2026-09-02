##############################################################################
#
# Backups — restic + optional rclone mirror
#
# Purpose
# -------
# Encrypted, deduplicated backups of the infrastructure checkout, system
# config, and operator dotfiles. The whole control plane depends on
# /home/ivali/nixos-infrastructure existing and clean, so Git is NOT a
# backup — this is. Off-machine (rclone -> S3/B2) is optional.
#
# Ownership
# ---------
# fleet.backup.*, systemd restic-backup.{service,timer}
#
# Dependencies
# ------------
# Requires SOPS secrets (created by the operator):
#   secrets/restic.yaml   -> restic_password
#   secrets/rclone.yaml   -> rclone config (only if useRclone)
# restic is CPU/IO light; runs at idle priority, daily by default.
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.fleet.backup;

  backupScript = pkgs.writeShellScript "restic-backup" ''
    #!/bin/sh
    set -eu

    LOCAL="''${1:-/mnt/backup}"
    USE_RCLONE="''${2:-false}"

    export RESTIC_PASSWORD_FILE=/run/secrets/restic_password

    if [ "$USE_RCLONE" = "true" ]; then
      export RCLONE_CONFIG=/run/secrets/restic_rclone
      REPO="rclone:restic-backup"
    else
      REPO="$LOCAL"
      # Local USB/disk not mounted -> skip gracefully, never fail the boot.
      if [ ! -d "$LOCAL" ]; then
        echo "backup target $LOCAL not mounted; skipping"
        exit 0
      fi
    fi

    export RESTIC_REPOSITORY="$REPO"

    if ! restic cat config >/dev/null 2>&1; then
      echo "initializing restic repo at $REPO"
      restic init || { echo "restic init failed; skipping"; exit 0; }
    fi

    restic backup \
      --exclude=/home/ivali/.cache \
      --exclude=/home/ivali/.cargo \
      --exclude=/home/ivali/.rustup \
      --exclude=/nix/store \
      --exclude=/var/lib/docker \
      /home/ivali/nixos-infrastructure \
      /etc \
      /root \
      /home/ivali/.config

    restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 3
    restic check || echo "WARNING: restic repository integrity check failed" >&2
  '';
in
{
  options.fleet.backup = {
    enable = lib.mkEnableOption "restic + rclone backups";

    localPath = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/backup";
      description = "Local restic repository path (e.g. a mounted USB disk).";
    };

    useRclone = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Also mirror the repository to a remote via rclone (S3/B2).";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      example = "*-*-* 03:00:00";
      description = "systemd OnCalendar expression for the backup timer.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.restic pkgs.rclone ];

    sops.secrets.restic_password = {
      sopsFile = ../secrets/restic.yaml;
      owner = "root";
      mode = "0400";
    };

    sops.secrets.restic_rclone = lib.mkIf cfg.useRclone {
      sopsFile = ../secrets/rclone.yaml;
      owner = "root";
      mode = "0400";
    };

    systemd.services.restic-backup = {
      description = "Restic backup (local + optional rclone mirror)";
      serviceConfig = {
        Type = "oneshot";
        Nice = 19;
        IOSchedulingClass = "idle";
        ExecStart = "${backupScript} ${cfg.localPath} ${lib.boolToString cfg.useRclone}";
      };
    };

    systemd.timers.restic-backup = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
        RandomizedDelaySec = "30min";
      };
    };
  };
}
