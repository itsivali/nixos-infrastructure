##############################################################################
#
# Rollback
#
# Purpose
# -------
# Self-heal service that runs on system health failure.
# Rollback is handled by gitops-reconcile.sh when the health gate
# fails post-deployment. This module exists as a safety net.
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

  config = lib.mkIf (cfg.enable or false) {
    systemd.services.rollback-on-failure = {
      description = "Rollback on deployment health failure";

      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };

      script = ''
        if ! ${./../scripts/deployment-health.sh}; then
          ${./../scripts/rollback.sh}
        fi
      '';
    };
  };
}
