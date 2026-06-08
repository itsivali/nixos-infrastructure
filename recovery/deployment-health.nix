{ config, pkgs, ... }:

{
  systemd.services.deployment-health = {
    description = "Deployment health check";

    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };

    script = "${./../scripts/deployment-health.sh}";
  };

  systemd.timers.deployment-health = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/5";
      Persistent = true;
    };
  };
}
