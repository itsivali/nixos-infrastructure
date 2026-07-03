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

    falco.profile = lib.mkOption {
      type = lib.types.enum [ "workstation" "server" "custom" ];
      default = "workstation";
      description = ''
        Falco rule profile:
        - workstation: Desktop-focused rules (browsers, containers, user activity)
        - server: Server-focused rules (SSH, services, network)
        - custom: Use custom rules file
      '';
    };

    falco.customRulesFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to custom Falco rules file (used when profile = custom)";
    };

    falco.enableJsonOutput = lib.mkEnableOption "Falco JSON output format";

    falco.syscallEvents = lib.mkEnableOption "Log all syscall events";

    alloy.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Forward journal logs to Loki using Grafana Alloy.";
    };

    otel.enable = lib.mkEnableOption "OpenTelemetry collector";

    otel.enablePrometheusForwarding = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Forward metrics to Prometheus remote write";
    };

    otel.enableLoggingExporter = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable logging exporter for debugging";
    };

    otel.samplingRate = lib.mkOption {
      type = lib.types.float;
      default = 0.1;
      description = "Trace sampling rate (0.0 to 1.0)";
    };

    lokiUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://${lokiListenAddress}:${toString lokiPort}/loki/api/v1/push";
      description = "Loki push endpoint for Grafana Alloy.";
    };
  };
}
