##############################################################################
#
# Nginx Configuration
#
# Purpose
# -------
# Web server and reverse proxy for local services.
#
# Ownership
# ---------
# services.nginx, networking.firewall
#
# Responsibilities
# ----------------
# - Reverse proxy for Grafana (localhost:3000)
# - Reverse proxy for Prometheus (localhost:9090)
# - Static file serving
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
            proxyPass = "http://127.0.0.1:3000/";
            proxyWebsockets = true;
          };
          "/prometheus/" = {
            proxyPass = "http://127.0.0.1:9090/";
          };
        };
      };
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}
