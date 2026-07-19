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
        if ! ${./../scripts/deployment-health.sh}; then
          ${./../scripts/rollback.sh}
        fi
      '';
    };
  };
}
