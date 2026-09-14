##############################################################################
#
# Prometheus
#
# Purpose
# -------
# Local Prometheus metrics collection and node exporter.
# Optimized for low CPU usage on a laptop.
#
# Ownership
# ---------
# services.prometheus, services.prometheus.exporters.node
#
# Responsibilities
# ----------------
# - Multi-host label injection
# - Configurable retention policies
# - Scrape target management
#
##############################################################################

{ config, lib, ... }:

let
  cfg = config.ivali.observability;
  prometheusListenAddress = "127.0.0.1";
  prometheusPort = 9090;
  hostName = config.networking.hostName;
in
{
  options.ivali.observability.prometheus = {
    retentionTime = lib.mkOption {
      type = lib.types.str;
      default = "3d";
      description = "Prometheus data retention period";
    };

    scrapeInterval = lib.mkOption {
      type = lib.types.str;
      default = "120s";
      description = "Prometheus scrape interval";
    };

    enableMultiHostLabels = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Add host label to all scraped metrics";
    };
  };

  config = lib.mkIf cfg.enable {
    services.prometheus = {
      enable = true;
      listenAddress = prometheusListenAddress;
      port = prometheusPort;
      webExternalUrl = "http://localhost/prometheus/";
      retentionTime = cfg.prometheus.retentionTime;
      globalConfig = {
        scrape_interval = cfg.prometheus.scrapeInterval;
        evaluation_interval = cfg.prometheus.scrapeInterval;
      };
      scrapeConfigs =
        [
          {
            job_name = "node";
            static_configs = [
              {
                targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ];
                labels = {
                  host = hostName;
                  environment = "production";
                };
              }
            ];
            scrape_interval = "60s";
          }
          {
            job_name = "prometheus";
            static_configs = [
              {
                targets = [ "${prometheusListenAddress}:${toString prometheusPort}" ];
                labels = {
                  host = hostName;
                };
              }
            ];
          }
        ]
        # Scrape targets for every enabled observability/service component.
        # Each target must have a matching enabled service; the CI check
        # ci/check-scrape-targets.sh verifies this stays in sync.
        ++ lib.optionals cfg.alertmanager.enable [
          {
            job_name = "alertmanager";
            static_configs = [
              {
                targets = [ "127.0.0.1:9093" ];
                labels = { host = hostName; };
              }
            ];
            scrape_interval = "30s";
          }
        ]
        ++ lib.optionals cfg.enable [
          {
            job_name = "grafana";
            static_configs = [
              {
                targets = [ "127.0.0.1:3000" ];
                labels = { host = hostName; };
              }
            ];
            scrape_interval = "30s";
          }
        ]
        ++ lib.optionals cfg.loki.enable [
          {
            job_name = "loki";
            static_configs = [
              {
                targets = [ "127.0.0.1:3100" ];
                labels = { host = hostName; };
              }
            ];
            scrape_interval = "30s";
          }
        ]
        ++ lib.optionals cfg.alloy.enable [
          {
            job_name = "alloy";
            static_configs = [
              {
                targets = [ "127.0.0.1:12345" ];
                labels = { host = hostName; };
              }
            ];
            scrape_interval = "30s";
          }
        ]
        ++ lib.optionals cfg.exporters.enable [
          {
            job_name = "nixos-exporter";
            static_configs = [
              {
                targets = [ "127.0.0.1:9101" ];
                labels = { host = hostName; };
              }
            ];
            scrape_interval = "30s";
          }
        ]
        ++ lib.optionals (lib.attrByPath [ "ivali" "services" "webUI" "enable" ] false config) [
          {
            job_name = "ivali-api";
            static_configs = [
              {
                targets = [ "127.0.0.1:${toString config.ivali.services.webUI.port}" ];
                labels = { host = hostName; };
              }
            ];
            scrape_interval = "30s";
          }
        ]
        ++ lib.optionals (config.services.blocky.enable or false) [
          {
            job_name = "blocky";
            static_configs = [
              {
                targets = [ "127.0.0.1:4000" ];
                labels = { host = hostName; };
              }
            ];
            scrape_interval = "30s";
          }
        ]
        ++ lib.optionals (config.ivali.observability.healthEndpoint.enable or false) [
          {
            job_name = "health-endpoint";
            static_configs = [
              {
                targets = [ "127.0.0.1:${toString (config.ivali.observability.healthEndpoint.port or 9710)}" ];
                labels = { host = hostName; };
              }
            ];
            scrape_interval = "30s";
          }
        ]
        ++ lib.optionals (config.ivali.tailscale.enable or false) [
          {
            job_name = "tailscale";
            static_configs = [
              {
                targets = [ "127.0.0.1:9121" ];
                labels = { host = hostName; };
              }
            ];
            scrape_interval = "30s";
          }
        ]
        ++ lib.optionals (config.ivali.security.scanning.enable or false) [
          {
            job_name = "security-scanner";
            static_configs = [
              {
                targets = [ "127.0.0.1:${toString (config.ivali.security.scanning.metricsPort or 9120)}" ];
                labels = { host = hostName; };
              }
            ];
            scrape_interval = "30s";
          }
        ]
        ++ lib.optionals (config.ivali.observability.otel.enable or false) [
          {
            job_name = "otelcol";
            static_configs = [
              {
                targets = [ "127.0.0.1:8888" ];
                labels = { host = hostName; };
              }
            ];
            scrape_interval = "60s";
          }
        ];
      exporters.node = {
        enable = true;
        enabledCollectors = [
          "systemd"
          "processes"
          "cpu"
          "meminfo"
          "diskstats"
          "filesystem"
          "loadavg"
          "netdev"
          "stat"
          "time"
          "uname"
          "vmstat"
        ];
        openFirewall = false;
      };
    };
  };
}
