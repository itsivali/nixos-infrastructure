##############################################################################
#
# Nginx
#
# Purpose
# -------
# Web server and reverse proxy for local services.
#
# Ownership
# ---------
# services.nginx
#
# Responsibilities
# ----------------
# - Reverse proxy for Grafana (localhost:3000)
# - Reverse proxy for Prometheus (localhost:9090)
# - Static file serving
#
# Usage
# -----
# ivali.observability.nginx.enable = true;
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.services.nginx;
in
{
  options.ivali.services.nginx = {
    enable = lib.mkEnableOption "Nginx web server";
  };

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
