##############################################################################
#
# Nginx Configuration
#
# Purpose
# -------
# Web server and reverse proxy for local services.
# Exposes Grafana, Prometheus, Loki, and Health endpoint via HTTP.
#
# Ownership
# ---------
# services.nginx, networking.firewall
#
# Responsibilities
# ----------------
# - Reverse proxy for Grafana (/grafana/)
# - Reverse proxy for Prometheus (/prometheus/)
# - Reverse proxy for Loki (/loki/)
# - Reverse proxy for Health endpoint (/health/)
#
##############################################################################

{ config, lib, ... }:

let
  cfg = config.ivali.services.nginx;
in
{
  config = lib.mkIf cfg.enable {
    services.nginx = {
      enable = true;

      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      virtualHosts."localhost" = {
        locations = {
          "/grafana/" = {
            proxyPass = "http://127.0.0.1:3000/grafana/";
            proxyWebsockets = true;
          };
          "/prometheus/" = {
            proxyPass = "http://127.0.0.1:9090/";
          };
          "/loki/" = {
            proxyPass = "http://127.0.0.1:3100/";
          };
          "/health" = {
            proxyPass = "http://127.0.0.1:9100/";
          };
        };
      };
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}
