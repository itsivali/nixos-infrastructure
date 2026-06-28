##############################################################################
#
# Grafana Alloy
#
# Purpose
# -------
# Forward systemd journal logs to Loki.
#
# Ownership
# ---------
# services.alloy, environment.etc."alloy/config.alloy"
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.observability;
in
{
  environment.etc."alloy/config.alloy" = lib.mkIf (cfg.enable && cfg.alloy.enable) {
    text = ''
      logging {
        level = "info"
      }

      loki.write "default" {
        endpoint {
          url = "${cfg.lokiUrl}"
        }
      }

      loki.source.journal "systemd" {
        forward_to = [loki.write.default.receiver]

        labels = {
          host = "${config.networking.hostName}"
          job  = "systemd-journal"
        }
      }
    '';
  };

  systemd.services.alloy = lib.mkIf (cfg.enable && cfg.alloy.enable) {
    description = "Grafana Alloy";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "loki.service" ];
    wants = [ "network-online.target" "loki.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.grafana-alloy}/bin/alloy run /etc/alloy/config.alloy";
      Restart = "always";
      RestartSec = "10s";
    };
  };
}
