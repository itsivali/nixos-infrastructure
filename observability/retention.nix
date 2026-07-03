##############################################################################
#
# Retention Policies
#
# Purpose
# -------
# Configure retention policies for metrics, logs, and traces.
# Different data types have different retention requirements.
#
# Ownership
# ---------
# services.prometheus, services.loki
#
# Responsibilities
# ----------------
# - Metrics retention (Prometheus)
# - Log retention (Loki)
# - Trace retention (OTel)
# - Storage optimization
#
##############################################################################

{ config, lib, ... }:

let
  cfg = config.ivali.observability;
in
{
  options.ivali.observability.retention = {
    enable = lib.mkEnableOption "Retention policies for observability data";

    metricsRetention = lib.mkOption {
      type = lib.types.str;
      default = "15d";
      description = "Prometheus metrics retention period";
    };

    logsRetention = lib.mkOption {
      type = lib.types.str;
      default = "7d";
      description = "Loki logs retention period";
    };

    tracesRetention = lib.mkOption {
      type = lib.types.str;
      default = "3d";
      description = "OpenTelemetry traces retention period";
    };

    enableCompaction = lib.mkEnableOption "Loki compaction for storage optimization";

    enableDownsampling = lib.mkEnableOption "Prometheus downsampling for old metrics";
  };

  config = lib.mkIf (cfg.enable && cfg.retention.enable) {
    # Prometheus retention
    services.prometheus = {
      retentionTime = cfg.retention.metricsRetention;

      # Add retention-related alerting rules
      ruleFiles = [
        (builtins.toFile "retention-rules.yml" ''
          groups:
            - name: retention
              rules:
                # Storage usage alert
                - alert: StorageUsageHigh
                  expr: |
                    (node_filesystem_avail_bytes{mountpoint="/var/lib/prometheus"} / node_filesystem_size_bytes{mountpoint="/var/lib/prometheus"}) * 100 < 20
                  for: 5m
                  labels:
                    severity: warning
                  annotations:
                    summary: "Prometheus storage low on {{ $labels.instance }}"
                    description: "Less than 20% storage available for metrics"

                # Loki storage usage alert
                - alert: LokiStorageUsageHigh
                  expr: |
                    (node_filesystem_avail_bytes{mountpoint="/var/lib/loki"} / node_filesystem_size_bytes{mountpoint="/var/lib/loki"}) * 100 < 20
                  for: 5m
                  labels:
                    severity: warning
                  annotations:
                    summary: "Loki storage low on {{ $labels.instance }}"
                    description: "Less than 20% storage available for logs"
        '')
      ];
    };

    # Loki retention
    services.loki = {
      # Configure retention through limits
      extraConfig = {
        limits_config = {
          retention_period = cfg.retention.logsRetention;
          retention_deletes_enabled = true;
        };

        compactor = {
          compaction_interval = "10m";
          retention_enabled = cfg.retention.enableCompaction;
          retention_delete_delay = "2h";
          retention_delete_worker_count = 150;
          delete_fetch_batch_size = 1000;
        };
      };
    };

    # Storage directories configuration
    systemd.services.prometheus = {
      serviceConfig = {
        # Ensure proper storage directory
        StateDirectory = "prometheus";
        StateDirectoryMode = "0755";
      };
    };

    systemd.services.loki = {
      serviceConfig = {
        # Ensure proper storage directory
        StateDirectory = "loki";
        StateDirectoryMode = "0755";
      };
    };
  };
}
