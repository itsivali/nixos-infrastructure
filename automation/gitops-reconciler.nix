{ config, pkgs, ... }:

{
  systemd.services.gitops-reconciler = {
    description = "GitOps reconciliation loop";

    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };

    script = "${./../scripts/gitops-reconcile.sh}";
  };

  systemd.timers.gitops-reconciler = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/15";
      Persistent = true;
    };
  };
}
