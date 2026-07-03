##############################################################################
#
# Prometheus Alerting Rules
#
# Purpose
# -------
# Define alerting rules for critical system conditions.
#
# Ownership
# ---------
# services.prometheus
#
# Responsibilities
# ----------------
# - Disk space warnings
# - Service failure detection
# - Generation drift alerts
# - High CPU/memory usage
#
##############################################################################

{ config, lib, ... }:

let
  cfg = config.ivali.observability;
in
{
  services.prometheus = lib.mkIf cfg.enable {
    ruleFiles = [
      (builtins.toFile "alerting-rules.yml" ''
        groups:
          - name: system
            rules:
              # Disk space warnings
              - alert: DiskSpaceLow
                expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 20
                for: 5m
                labels:
                  severity: warning
                annotations:
                  summary: "Disk space low on {{ $labels.instance }}"
                  description: "Less than 20% disk space available on {{ $labels.mountpoint }}"

              - alert: DiskSpaceCritical
                expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 10
                for: 5m
                labels:
                  severity: critical
                annotations:
                  summary: "Disk space critical on {{ $labels.instance }}"
                  description: "Less than 10% disk space available on {{ $labels.mountpoint }}"

              # Service failures
              - alert: SystemdServiceFailed
                expr: node_systemd_unit_state{state="failed"} == 1
                for: 1m
                labels:
                  severity: warning
                annotations:
                  summary: "Service {{ $labels.name }} failed"
                  description: "Systemd service {{ $labels.name }} has failed"

              - alert: SystemdServiceCrashLooping
                expr: rate(node_systemd_unit_state{state="failed"}[5m]) > 0.1
                for: 5m
                labels:
                  severity: critical
                annotations:
                  summary: "Service {{ $labels.name }} crash-looping"
                  description: "Service {{ $labels.name }} is crash-looping"

              # CPU usage
              - alert: HighCpuUsage
                expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
                for: 10m
                labels:
                  severity: warning
                annotations:
                  summary: "High CPU usage on {{ $labels.instance }}"
                  description: "CPU usage above 80% for 10 minutes"

              # Memory usage
              - alert: HighMemoryUsage
                expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
                for: 5m
                labels:
                  severity: warning
                annotations:
                  summary: "High memory usage on {{ $labels.instance }}"
                  description: "Memory usage above 85%"

              # NixOS generation drift
              - alert: GenerationDrift
                expr: node_systemd_unit_state{name="nixos-optimise.service", state="active"} == 0
                for: 1h
                labels:
                  severity: info
                annotations:
                  summary: "NixOS generation drift detected"
                  description: "System generations may need optimization"

          - name: nixos
            rules:
              # NixOS rebuild failures
              - alert: NixOSRebuildFailed
                expr: node_systemd_unit_state{name=~".*rebuild.*", state="failed"} == 1
                for: 1m
                labels:
                  severity: critical
                annotations:
                  summary: "NixOS rebuild failed"
                  description: "NixOS system rebuild has failed"

              # Home Manager activation failures
              - alert: HomeManagerFailed
                expr: node_systemd_unit_state{name=~".*home-manager.*", state="failed"} == 1
                for: 1m
                labels:
                  severity: warning
                annotations:
                  summary: "Home Manager activation failed"
                  description: "Home Manager activation has failed"

      '')
    ];

    alertmanagers = lib.mkIf config.services.prometheus.enable [
      {
        static_configs = [
          { targets = [ "127.0.0.1:9093" ]; }
        ];
      }
    ];
  };
}
