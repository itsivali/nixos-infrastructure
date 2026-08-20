##############################################################################
#
# Rollback
#
# Purpose
# -------
# Self-heal service triggered by deployment-health.service (OnFailure) when a
# critical service is down. It re-runs the health check in OBSERVER mode
# (STRICT_HEALTH=false): connectivity / GitLab / bot-API failures are only
# WARN there, so a transient network blip does NOT roll back. A genuine
# service regression (e.g. ivali-bot-go stopped) still FAILs and rolls back.
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
        procps
        git
        nix
        nixos-rebuild
        findutils
        # Include the system bin so the `sendmail` symlink (programs.msmtp)
        # resolves when notify.sh runs from this service.
        "/run/current-system/sw/bin"
      ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";

        # Re-check in observer mode so a network blip does not trigger a rollback.
        Environment = "STRICT_HEALTH=false";

        TimeoutStartSec = "120s";
        StandardOutput = "journal";
        StandardError = "journal";
        SyslogIdentifier = "rollback-on-failure";
      };

      script = ''
        # Wait for services to settle after the triggering health failure
        sleep 30

        # Guard: skip rollback if a nixos-rebuild is still running (e.g. the
        # deploy that triggered this service hasn't finished yet). Running
        # nixos-rebuild switch --rollback concurrently with another
        # nixos-rebuild switch corrupts the system profile.
        if pgrep -x nixos-rebuild >/dev/null 2>&1; then
          echo "nixos-rebuild is running — skipping rollback"
          exit 0
        fi

        # Run health check in observer mode; suppress stderr to avoid noisy
        # curl/nix warnings being treated as errors by the rebuild script.
        if ! ${./../scripts/deployment-health.sh} 2>/dev/null; then
          ${./../scripts/rollback.sh}
        fi
      '';
    };
  };
}
