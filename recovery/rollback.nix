##############################################################################
#
# Rollback
#
# Purpose
# -------
# Self-heal service triggered by deployment-health.service (OnFailure) when a
# critical service is down. It re-runs the health check in OBSERVER mode
# (STRICT_HEALTH=false): connectivity / GitLab failures are only
# WARN there, so a transient network blip does NOT roll back. A genuine
# service regression (e.g. operations-web-ui stopped) still FAILs and rolls back.
#
# The post-deploy gate in gitops-reconcile.sh is the primary rollback path.
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.fleet.deploymentHealth;
in
{
  options.fleet.deploymentHealth = {
    enableRollback = lib.mkEnableOption "automatic rollback on health failure";
  };

  config = lib.mkIf (cfg.enableRollback or false) {
    systemd.services.rollback-on-failure = {
      description = "Rollback on deployment health failure";

      path = with pkgs; [
        bash
        coreutils
        curl
        gnugrep
        gnused
        gawk
        iputils
        inetutils
        systemd
        git
        nix
        nixos-rebuild
        findutils
        util-linux # flock (deploy lock serialization)
        # Include the system bin so the `sendmail` symlink (programs.msmtp)
        # resolves when notify.sh runs from this service.
        "/run/current-system/sw/bin"
      ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";

        # Re-check in observer mode so a network blip does not trigger a rollback.
        Environment = "STRICT_HEALTH=false";

        # rollback.sh writes its hysteresis timestamp here; keep the dir writable.
        StateDirectory = "deployment-health";
        ReadWritePaths = [ "/var/lib/deployment-health" ];

        TimeoutStartSec = "120s";
        StandardOutput = "journal";
        StandardError = "journal";
        SyslogIdentifier = "rollback-on-failure";
      };

      script = ''
        # Wait for services to settle after the triggering health failure
        sleep 30

        # Guard: skip rollback if another deployment is still running (e.g. the
        # gitops-reconcile.sh that triggered this service hasn't finished yet).
        # Running nixos-rebuild switch --rollback concurrently with another
        # nixos-rebuild switch corrupts the system profile. Use flock on the
        # shared deploy lock (same lock used by gitops-reconcile.sh and
        # ci-deploy.sh) rather than pgrep, which is fragile against process
        # renaming and does not cover all concurrent mutation paths.
        exec 9>/run/deploy.lock
        if ! flock -n 9; then
          echo "Another deployment is in progress — skipping rollback"
          exit 0
        fi
        # Keep the lock held for the rest of this script to prevent a new
        # reconcile from starting while we roll back.
        # (fd 9 stays open until the script exits.)

        # Run health check in observer mode; suppress stderr to avoid noisy
        # curl/nix warnings being treated as errors by the rebuild script.
        if ! ${./../scripts/deployment-health.sh} 2>/dev/null; then
          ${./../scripts/rollback.sh}
        fi
      '';
    };
  };
}
