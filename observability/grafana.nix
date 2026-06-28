##############################################################################
#
# Grafana
#
# Purpose
# -------
# Local Grafana dashboard server with provisioned data sources.
#
# Ownership
# ---------
# services.grafana, sops.secrets.grafana_secret_key
#
##############################################################################

{ config, lib, ... }:

let
  cfg = config.ivali.observability;
  grafanaListenAddress = "127.0.0.1";
  grafanaPort = 3000;
  prometheusListenAddress = "127.0.0.1";
  prometheusPort = 9090;
  lokiListenAddress = "127.0.0.1";
  lokiPort = 3100;
in
{
  sops.secrets.grafana_secret_key = lib.mkIf (cfg.enable && config.ivali.secrets.enable) {
    owner = "grafana";
  };

  services.grafana = lib.mkIf cfg.enable {
    enable = true;
    settings = {
      server = {
        http_addr = grafanaListenAddress;
        http_port = grafanaPort;
        domain = "localhost";
      };
      analytics.reporting_enabled = false;
      security =
        {
          admin_user = "admin";
          disable_gravatar = true;
          secret_key = "SW2YcwTIb9zpOOhoPsMm";
        }
        // lib.optionalAttrs config.ivali.secrets.enable {
          secret_key = "$__file{${config.sops.secrets.grafana_secret_key.path}}";
        };
    };
    provision = {
      enable = true;
      datasources.settings = {
        apiVersion = 1;
        datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://${prometheusListenAddress}:${toString prometheusPort}";
            isDefault = true;
          }
          {
            name = "Loki";
            type = "loki";
            access = "proxy";
            url = "http://${lokiListenAddress}:${toString lokiPort}";
          }
        ];
      };
    };
  };
}
