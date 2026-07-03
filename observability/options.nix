##############################################################################
#
# Observability Options
#
# Purpose
# -------
# Declare the ivali.observability option namespace.
#
# Ownership
# ---------
# options.ivali.observability
#
# Does NOT Own
# ------------
# - Any service configuration
#
##############################################################################

{ lib, ... }:

let
  lokiListenAddress = "127.0.0.1";
  lokiPort = 3100;
in
{
  options.ivali.observability = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the local laptop monitoring stack.";
    };

    falco.enable = lib.mkEnableOption "Falco runtime detection";

    alloy.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Forward journal logs to Loki using Grafana Alloy.";
    };

    otel.enable = lib.mkEnableOption "OpenTelemetry collector";

    lokiUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://${lokiListenAddress}:${toString lokiPort}/loki/api/v1/push";
      description = "Loki push endpoint for Grafana Alloy.";
    };

    exporters.enable = lib.mkEnableOption "NixOS Prometheus exporter";

    healthEndpoint.enable = lib.mkEnableOption "Health check HTTP endpoint";
  };
}
