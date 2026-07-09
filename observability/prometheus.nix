##############################################################################
#
# Prometheus
#
# Purpose
# -------
# Local Prometheus metrics collection and node exporter.
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
      scrapeConfigs = [
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
      ];
      exporters.node = {
        enable = true;
        enabledCollectors = [ "systemd" "processes" ];
        openFirewall = false;
      };
    };
  };
}
