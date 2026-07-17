##############################################################################
#
# Grafana Dashboard Provisioning
#
# Purpose
# -------
# Provision detailed Grafana dashboards for NixOS monitoring.
# Dashboards are written as proper Grafana JSON at system activation time.
#
# Ownership
# ---------
# services.grafana, system.activationScripts.grafana-dashboards
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.observability;

  # Helper to create a stat panel
  statPanel = title: expr: unit: {
    inherit title;
    type = "stat";
    targets = [{ inherit expr; legendFormat = title; RefId = "A"; }];
    fieldConfig = {
      defaults = {
        thresholds = {
          steps = [
            { color = "green"; value = null; }
            { color = "yellow"; value = 80; }
            { color = "red"; value = 95; }
          ];
        };
        unit = unit;
      };
    };
    options = {
      reduceOptions = { calcs = [ "lastNotNull" ]; fields = ""; values = false; };
      colorMode = "background";
      graphMode = "area";
      justifyMode = "auto";
      textMode = "auto";
    };
  };

  # Helper to create a timeseries panel
  tsPanel = title: targets: unit: {
    inherit title;
    type = "timeseries";
    targets = map (t: { RefId = "A"; } // t) targets;
    fieldConfig = {
      defaults = {
        unit = unit;
        custom = {
          drawStyle = "line";
          lineWidth = 2;
          fillOpacity = 15;
          gradientMode = "scheme";
          showPoints = "auto";
          pointSize = 5;
          stacking = { mode = "none"; group = "A"; };
        };
      };
    };
    options = {
      legend = { displayMode = "list"; placement = "bottom"; };
      tooltip = { mode = "multi"; sort = "desc"; };
    };
  };

  # ─── Dashboard 1: NixOS System Overview ──────────────────────────────
  nixosSystemDashboard = {
    id = null;
    uid = "nixos-system-overview";
    title = "NixOS System Overview";
    tags = [ "nixos" "system" "overview" ];
    timezone = "browser";
    schemaVersion = 39;
    version = 1;
    refresh = "10s";
    time = { from = "now-1h"; to = "now"; };
    templating = { list = [ ]; };
    annotations = { list = [ ]; };
    panels = [
      # Row 1: Key metrics
      (statPanel "CPU Usage" "100 - (avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)" "percent")
      (statPanel "Memory Usage" "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100" "percent")
      (statPanel "Disk Usage" "(1 - (node_filesystem_avail_bytes{mountpoint=\"/\"} / node_filesystem_size_bytes{mountpoint=\"/\"})) * 100" "percent")
      (statPanel "System Load" "node_load1" "short")

      # Row 2: Time series
      (tsPanel "CPU Usage Over Time" [
        { expr = "100 - (avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)"; legendFormat = "CPU %"; }
        { expr = "avg(rate(node_cpu_seconds_total{mode=\"system\"}[5m])) * 100"; legendFormat = "System"; }
        { expr = "avg(rate(node_cpu_seconds_total{mode=\"user\"}[5m])) * 100"; legendFormat = "User"; }
        { expr = "avg(rate(node_cpu_seconds_total{mode=\"iowait\"}[5m])) * 100"; legendFormat = "IO Wait"; }
      ] "percent")
      (tsPanel "Memory Usage Over Time" [
        { expr = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100"; legendFormat = "Used %"; }
        { expr = "node_memory_Buffers_bytes / 1024 / 1024"; legendFormat = "Buffers (MB)"; }
        { expr = "node_memory_Cached_bytes / 1024 / 1024"; legendFormat = "Cached (MB)"; }
      ] "percent")

      # Row 3: Disk & Load
      (tsPanel "Disk Usage" [
        { expr = "(1 - (node_filesystem_avail_bytes{mountpoint=\"/\"} / node_filesystem_size_bytes{mountpoint=\"/\"})) * 100"; legendFormat = "Root /"; }
        { expr = "(1 - (node_filesystem_avail_bytes{mountpoint=\"/home\"} / node_filesystem_size_bytes{mountpoint=\"/home\"})) * 100"; legendFormat = "/home"; }
      ] "percent")
      (tsPanel "System Load" [
        { expr = "node_load1"; legendFormat = "1m"; }
        { expr = "node_load5"; legendFormat = "5m"; }
        { expr = "node_load15"; legendFormat = "15m"; }
        { expr = "count(node_cpu_seconds_total{mode=\"idle\"})"; legendFormat = "CPU Cores"; }
      ] "short")

      # Row 4: NixOS & Network
      (statPanel "NixOS Generation" "nixos_generation_current" "short")
      (statPanel "Uptime" "node_time_seconds - node_boot_time_seconds" "s")
      (tsPanel "Network Traffic" [
        { expr = "rate(node_network_receive_bytes_total{device!~\"lo|tailscale.*\"}[5m]) * 8"; legendFormat = "{{ device }} RX"; }
        { expr = "rate(node_network_transmit_bytes_total{device!~\"lo|tailscale.*\"}[5m]) * 8"; legendFormat = "{{ device }} TX"; }
      ] "bps")
      (statPanel "Nix Store Size" "nixos_store_size_bytes" "decbytes")
    ];
  };

  # ─── Dashboard 2: Services Health ────────────────────────────────────
  servicesHealthDashboard = {
    id = null;
    uid = "services-health";
    title = "Services Health";
    tags = [ "nixos" "services" "systemd" ];
    timezone = "browser";
    schemaVersion = 39;
    version = 1;
    refresh = "30s";
    time = { from = "now-6h"; to = "now"; };
    templating = { list = [ ]; };
    annotations = { list = [ ]; };
    panels = [
      (statPanel "Active Services" "count(node_systemd_unit_state{state=\"active\"})" "short")
      (statPanel "Failed Services" "count(node_systemd_unit_state{state=\"failed\"})" "short")
      (statPanel "Total Units" "count(node_systemd_unit_state)" "short")

      {
        title = "Failed Systemd Units";
        type = "table";
        targets = [{
          expr = "node_systemd_unit_state{state=\"failed\"}";
          format = "table";
          instant = true;
          RefId = "A";
        }];
        fieldConfig = {
          defaults = { };
          overrides = [ ];
        };
        options = {
          showHeader = true;
          sortBy = [{ displayName = "Value"; desc = true; }];
        };
        gridPos = { h = 10; w = 24; x = 0; y = 4; };
      }

      (tsPanel "Service Uptime" [
        { expr = "node_systemd_unit_state{name=~\"prometheus.service|grafana.service|loki.service|nginx.service|alloy.service|ivali-bot-go.service|tailscaled.service\", state=\"active\"}"; legendFormat = "{{ name }}"; }
      ] "short")

      {
        title = "Critical Services Status";
        type = "stat";
        targets = [
          { expr = "node_systemd_unit_state{name=\"prometheus.service\", state=\"active\"}"; legendFormat = "Prometheus"; RefId = "A"; }
          { expr = "node_systemd_unit_state{name=\"grafana.service\", state=\"active\"}"; legendFormat = "Grafana"; RefId = "B"; }
          { expr = "node_systemd_unit_state{name=\"loki.service\", state=\"active\"}"; legendFormat = "Loki"; RefId = "C"; }
          { expr = "node_systemd_unit_state{name=\"nginx.service\", state=\"active\"}"; legendFormat = "Nginx"; RefId = "D"; }
          { expr = "node_systemd_unit_state{name=\"alloy.service\", state=\"active\"}"; legendFormat = "Alloy"; RefId = "E"; }
          { expr = "node_systemd_unit_state{name=\"ivali-bot-go.service\", state=\"active\"}"; legendFormat = "Bot"; RefId = "F"; }
          { expr = "node_systemd_unit_state{name=\"tailscaled.service\", state=\"active\"}"; legendFormat = "Tailscale"; RefId = "G"; }
        ];
        fieldConfig = {
          defaults = {
            mappings = [
              { type = "value"; options = { "0" = { text = "DOWN"; color = "red"; }; "1" = { text = "UP"; color = "green"; }; }; }
            ];
            thresholds = {
              steps = [
                { color = "red"; value = null; }
                { color = "green"; value = 1; }
              ];
            };
          };
        };
        options = {
          reduceOptions = { calcs = [ "lastNotNull" ]; fields = ""; values = false; };
          colorMode = "background";
          graphMode = "none";
          justifyMode = "auto";
          textMode = "auto";
        };
        gridPos = { h = 6; w = 24; x = 0; y = 14; };
      }
    ];
  };

  # ─── Dashboard 3: Network & Tailscale ────────────────────────────────
  networkDashboard = {
    id = null;
    uid = "network-tailscale";
    title = "Network & Tailscale";
    tags = [ "network" "tailscale" "vpn" ];
    timezone = "browser";
    schemaVersion = 39;
    version = 1;
    refresh = "30s";
    time = { from = "now-1h"; to = "now"; };
    templating = { list = [ ]; };
    annotations = { list = [ ]; };
    panels = [
      (tsPanel "Network Traffic" [
        { expr = "rate(node_network_receive_bytes_total{device!~\"lo|tailscale.*\"}[5m]) * 8"; legendFormat = "{{ device }} RX bps"; }
        { expr = "rate(node_network_transmit_bytes_total{device!~\"lo|tailscale.*\"}[5m]) * 8"; legendFormat = "{{ device }} TX bps"; }
      ] "bps")

      (tsPanel "Network Errors & Drops" [
        { expr = "rate(node_network_receive_errs_total{device!~\"lo\"}[5m])"; legendFormat = "{{ device }} RX errors"; }
        { expr = "rate(node_network_transmit_errs_total{device!~\"lo\"}[5m])"; legendFormat = "{{ device }} TX errors"; }
        { expr = "rate(node_network_receive_drop_total{device!~\"lo\"}[5m])"; legendFormat = "{{ device }} RX drops"; }
      ] "short")

      (statPanel "TCP Established" "node_netstat_Tcp_CurrEstab" "short")
      (statPanel "TCP Time Wait" "node_sockstat_TCP_tw" "short")

      (tsPanel "Tailscale Connection" [
        { expr = "tailscale_connected"; legendFormat = "Connected"; }
        { expr = "tailscale_key_expiry_days"; legendFormat = "Key Expiry (days)"; }
        { expr = "tailscale_magicdns_status"; legendFormat = "MagicDNS"; }
      ] "short")

      (statPanel "Tailscale IP" "tailscale_connected" "short")

      {
        title = "TCP Connections by State";
        type = "piechart";
        targets = [{
          expr = "node_sockstat_TCP_alloc";
          legendFormat = "Allocated";
          RefId = "A";
        }];
        gridPos = { h = 8; w = 8; x = 0; y = 12; };
      }

      (tsPanel "DNS Resolution Time" [
        { expr = "rate(dns_resolution_seconds_sum[5m]) / rate(dns_resolution_seconds_count[5m])"; legendFormat = "Avg DNS time"; }
      ] "s")
    ];
  };

  # ─── Dashboard 4: Logs Explorer ──────────────────────────────────────
  logsDashboard = {
    id = null;
    uid = "logs-explorer";
    title = "Logs Explorer";
    tags = [ "logs" "loki" "journald" ];
    timezone = "browser";
    schemaVersion = 39;
    version = 1;
    refresh = "30s";
    time = { from = "now-1h"; to = "now"; };
    templating = { list = [ ]; };
    annotations = { list = [ ]; };
    panels = [
      {
        title = "All Journal Entries";
        type = "logs";
        targets = [{
          expr = "{job=\"systemd-journal\"}";
          refId = "A";
        }];
        gridPos = { h = 12; w = 24; x = 0; y = 0; };
      }

      {
        title = "Failed Services";
        type = "logs";
        targets = [{
          expr = "{job=\"systemd-journal\"} |= \"Failed\"";
          refId = "A";
        }];
        gridPos = { h = 8; w = 12; x = 0; y = 12; };
      }

      {
        title = "Bot Logs";
        type = "logs";
        targets = [{
          expr = "{job=\"systemd-journal\", unit=\"ivali-bot-go.service\"}";
          refId = "A";
        }];
        gridPos = { h = 8; w = 12; x = 12; y = 12; };
      }

      {
        title = "Errors & Warnings";
        type = "logs";
        targets = [{
          expr = "{job=\"systemd-journal\"} |= \"error\" |~ \"(?i)(error|fail|crit|alert|emerg)\"";
          refId = "A";
        }];
        gridPos = { h = 8; w = 12; x = 0; y = 20; };
      }

      {
        title = "Nginx Access Logs";
        type = "logs";
        targets = [{
          expr = "{job=\"systemd-journal\", unit=\"nginx.service\"} |= \"GET\" or {job=\"systemd-journal\", unit=\"nginx.service\"} |= \"POST\"";
          refId = "A";
        }];
        gridPos = { h = 8; w = 12; x = 12; y = 20; };
      }
    ];
  };

  # All dashboards
  dashboards = {
    "nixos-system" = nixosSystemDashboard;
    "services-health" = servicesHealthDashboard;
    "network-tailscale" = networkDashboard;
    "logs-explorer" = logsDashboard;
  };

in
{
  system.activationScripts.grafana-dashboards = lib.mkIf cfg.enable ''
    mkdir -p /var/lib/grafana/dashboards/nixos

    ${builtins.concatStringsSep "\n" (lib.mapAttrsToList (name: dashboard:
      "cat > /var/lib/grafana/dashboards/nixos/${name}.json << 'DASHBOARD_EOF'\n${builtins.toJSON dashboard}\nDASHBOARD_EOF"
    ) dashboards)}
  '';
}
