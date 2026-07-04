##############################################################################
#
# Grafana
#
# Purpose
# -------
# Local Grafana dashboard server with provisioned data sources and dashboards.
#
# Ownership
# ---------
# services.grafana, sops.secrets.grafana_secret_key, sops.secrets.grafana_admin_password
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

  sops.secrets.grafana_admin_password = lib.mkIf (cfg.enable && config.ivali.secrets.enable) {
    owner = "grafana";
  };

  services.grafana = lib.mkIf cfg.enable {
    enable = true;
    settings = {
      server = {
        http_addr = grafanaListenAddress;
        http_port = grafanaPort;
        domain = "localhost";
        root_url = "%(protocol)s://%(domain)s:%(http_port)s/grafana/";
        serve_from_sub_path = true;
      };
      analytics.reporting_enabled = false;
      security = {
        admin_user = "admin";
        admin_password = "ivali";
        disable_gravatar = true;
        secret_key = "SW2YcwTIb9zpOOhoPsMm";
      } // lib.optionalAttrs config.ivali.secrets.enable {
        admin_password = "$__file{${config.sops.secrets.grafana_admin_password.path}}";
        secret_key = "$__file{${config.sops.secrets.grafana_secret_key.path}}";
      };
      users.allow_sign_up = false;
      log.mode = "console";
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
            jsonData = {
              timeInterval = "15s";
            };
          }
          {
            name = "Loki";
            type = "loki";
            access = "proxy";
            url = "http://${lokiListenAddress}:${toString lokiPort}";
          }
        ];
      };
      dashboards.settings = {
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
  };
}
