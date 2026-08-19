##############################################################################
#
# Grafana Alloy
#
# Purpose
# -------
# Forward systemd journal logs to Loki.
# Optimized for low CPU usage.
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
        level = "warn"
      }

      loki.write "default" {
        endpoint {
          url = "${cfg.lokiUrl}"
          batch {
            wait = "5s"
            max_items = 500
            max_entries_bytes = "1MB"
          }
          external_labels = {
            host = "${config.networking.hostName}"
          }
        }
      }

      loki.source.journal "systemd" {
        forward_to = [loki.write.default.receiver]

        labels = {
          host = "${config.networking.hostName}"
          job  = "systemd-journal"
        }

        # Forward only error-level and above to reduce storage and CPU.
        priority = ["err" "crit" "alert" "emerg"]

        relabel_rules = [
          {
            source_labels = ["__journal_priority_keyword"]
            target_label = "level"
          },
          {
            source_labels = ["__journal__systemd_unit"]
            target_label = "unit"
          },
        ]
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
      RestartSec = "30s";
      MemoryMax = "24M";
      MemoryHigh = "16M";
      CPUQuota = "0.5%";
      CPUWeight = 20;
    };
  };
}
