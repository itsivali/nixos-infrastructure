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
##############################################################################

{ config, lib, ... }:

let
  cfg = config.ivali.observability;
  prometheusListenAddress = "127.0.0.1";
  prometheusPort = 9090;
in
{
  services.prometheus = lib.mkIf cfg.enable {
    enable = true;
    listenAddress = prometheusListenAddress;
    port = prometheusPort;
    retentionTime = "15d";
    globalConfig = {
      scrape_interval = "15s";
      evaluation_interval = "15s";
    };
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ]; }
        ];
      }
      {
        job_name = "prometheus";
        static_configs = [
          { targets = [ "${prometheusListenAddress}:${toString prometheusPort}" ]; }
        ];
      }
    ];
    exporters.node = {
      enable = true;
      enabledCollectors = [ "systemd" "processes" ];
      openFirewall = false;
    };
  };
}
