##############################################################################
#
# OpenTelemetry Collector
#
# Purpose
# -------
# OpenTelemetry collector for traces and metrics export.
#
# Ownership
# ---------
# environment.etc."otelcol/config.yaml"
# systemd.services.opentelemetry-collector
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.observability;
in
{
  environment.etc."otelcol/config.yaml" = lib.mkIf cfg.otel.enable {
    text = ''
      receivers:
        otlp:
          protocols:
            grpc:
            http:
      processors:
        batch:
      exporters:
        logging:
          verbosity: basic
      service:
        pipelines:
          traces:
            receivers: [otlp]
            processors: [batch]
            exporters: [logging]
          metrics:
            receivers: [otlp]
            processors: [batch]
            exporters: [logging]
    '';
  };

  systemd.services.opentelemetry-collector = lib.mkIf cfg.otel.enable {
    description = "OpenTelemetry collector";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      ExecStart =
        let
          otelPkg =
            pkgs.opentelemetry-collector-contrib
              or pkgs.otelcol-contrib
              or pkgs.opentelemetry-collector;
        in
        "${otelPkg}/bin/otelcol --config=/etc/otelcol/config.yaml";
      Restart = "always";
      RestartSec = "10s";
    };
  };
}
