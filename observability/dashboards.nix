##############################################################################
#
# Grafana Dashboard Provisioning
#
# Purpose
# -------
# Automatically provision NixOS system dashboards in Grafana.
#
# Ownership
# ---------
# services.grafana
#
# Responsibilities
# ----------------
# - System overview dashboard
# - NixOS metrics dashboard
# - Service health dashboard
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.observability;

  dashboards = {
    "nixos-system" = {
      title = "NixOS System Overview";
      uid = "nixos-system-overview";
      tags = [ "nixos" "system" ];
      panels = [
        {
          title = "CPU Usage";
          type = "timeseries";
          targets = [
            {
              expr = "100 - (avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)";
              legendFormat = "CPU Usage %";
            }
          ];
          gridPos = { h = 8; w = 12; x = 0; y = 0; };
        }
        {
          title = "Memory Usage";
          type = "timeseries";
          targets = [
            {
              expr = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100";
              legendFormat = "Memory Usage %";
            }
          ];
          gridPos = { h = 8; w = 12; x = 12; y = 0; };
        }
        {
          title = "Disk Usage";
          type = "timeseries";
          targets = [
            {
              expr = "(1 - (node_filesystem_avail_bytes{mountpoint=\"/\"} / node_filesystem_size_bytes{mountpoint=\"/\"})) * 100";
              legendFormat = "Root Disk Usage %";
            }
          ];
          gridPos = { h = 8; w = 12; x = 0; y = 8; };
        }
        {
          title = "System Load";
          type = "timeseries";
          targets = [
            {
              expr = "node_load1";
              legendFormat = "1m Load Average";
            }
            {
              expr = "node_load5";
              legendFormat = "5m Load Average";
            }
            {
              expr = "node_load15";
              legendFormat = "15m Load Average";
            }
          ];
          gridPos = { h = 8; w = 12; x = 12; y = 8; };
        }
        {
          title = "Systemd Services";
          type = "table";
          targets = [
            {
              expr = "node_systemd_unit_state{state=\"active\"}";
              format = "table";
              instant = true;
            }
          ];
          gridPos = { h = 8; w = 24; x = 0; y = 16; };
        }
        {
          title = "NixOS Generations";
          type = "stat";
          targets = [
            {
              expr = "node_systemd_unit_state{name=\"nixos-optimise.service\", state=\"active\"}";
              legendFormat = "Optimized";
            }
          ];
          gridPos = { h = 4; w = 8; x = 0; y = 24; };
        }
        {
          title = "Uptime";
          type = "stat";
          targets = [
            {
              expr = "node_time_seconds - node_boot_time_seconds";
              legendFormat = "Uptime";
            }
          ];
          gridPos = { h = 4; w = 8; x = 8; y = 24; };
        }
        {
          title = "Network Interfaces";
          type = "timeseries";
          targets = [
            {
              expr = "rate(node_network_receive_bytes_total{device!~\"lo|tailscale.*\"}[5m]) * 8";
              legendFormat = "{{ device }} RX";
            }
            {
              expr = "rate(node_network_transmit_bytes_total{device!~\"lo|tailscale.*\"}[5m]) * 8";
              legendFormat = "{{ device }} TX";
            }
          ];
          gridPos = { h = 8; w = 12; x = 16; y = 24; };
        }
      ];
      time = { from = "now-1h"; to = "now"; };
      refresh = "10s";
    };
  };

  dashboardJson = builtins.toJSON {
    apiVersion = 1;
    providers = [
      {
        name = "NixOS";
        orgId = 1;
        folder = "NixOS";
        type = "file";
        disableDeletion = false;
        updateIntervalSeconds = 30;
        options = {
          path = "/var/lib/grafana/dashboards/nixos";
        };
      }
    ];
  };

in
{
  services.grafana = lib.mkIf cfg.enable {
    provision.dashboards.settings = {
      apiVersion = 1;
      providers = [
        {
          name = "NixOS";
          orgId = 1;
          folder = "NixOS";
          type = "file";
          disableDeletion = false;
          updateIntervalSeconds = 30;
          options = {
            path = "/var/lib/grafana/dashboards/nixos";
          };
        }
      ];
    };
  };

  # Create dashboard files
  system.activationScripts.grafana-dashboards = lib.mkIf cfg.enable ''
    mkdir -p /var/lib/grafana/dashboards/nixos

    ${builtins.concatStringsSep "\n" (lib.mapAttrsToList (name: dashboard:
      "cat > /var/lib/grafana/dashboards/nixos/${name}.json << 'DASHBOARD_EOF'\n${builtins.toJSON dashboard}\nDASHBOARD_EOF"
    ) dashboards)}
  '';
}
