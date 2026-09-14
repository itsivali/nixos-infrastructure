##############################################################################
#
# Nginx Options
#
# Purpose
# -------
# Option declarations for the Nginx module.
#
# Ownership
# ---------
# options.ivali.services.nginx
#
##############################################################################

{ lib, ... }:

{
  options.ivali.services.nginx = {
    enable = lib.mkEnableOption "Nginx web server";

    tailscaleOnly = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Restrict the HTTP/HTTPS ports to the Tailscale interface. When
        disabled, the ports are opened on all interfaces. The observability
        stack (Grafana/Prometheus/Loki) carries sensitive internal data, so
        keeping it Tailscale-only is strongly recommended.
      '';
    };
  };
}
