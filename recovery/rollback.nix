{ config, pkgs, ... }:

{
  systemd.services.self-heal = {
    description = "Rollback on failure";

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
}
