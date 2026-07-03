##############################################################################
#
# OpenTelemetry Collector
#
# Purpose
# -------
# OpenTelemetry collector for traces, metrics, and logs export.
# Enhanced configuration with multiple receivers and processors.
#
# Ownership
# ---------
# environment.etc."otelcol/config.yaml"
# systemd.services.opentelemetry-collector
#
# Responsibilities
# ----------------
# - OTLP trace collection
# - Prometheus metrics forwarding
# - Host metrics collection
# - Log collection from journald
# - Batch processing and export
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.observability;
  hostName = config.networking.hostName;
in
{
  config = lib.mkIf cfg.otel.enable {
    environment.etc."otelcol/config.yaml" = {
      text = ''
        receivers:
          otlp:
            protocols:
              grpc:
                endpoint: 0.0.0.0:4317
              http:
                endpoint: 0.0.0.0:4318

          hostmetrics:
            collection_interval: 30s
            scrapers:
              cpu:
              memory:
              disk:
              filesystem:
              network:
              processes:
              system:

          journald:
            oneat: true
            operations:
              - read

        processors:
          batch:
            timeout: 5s
            send_batch_size: 1024

          memory_limiter:
            check_interval: 1s
            limit_mib: 512
            spike_limit_mib: 128

          attributes:
            actions:
              - key: host.name
                value: "${hostName}"
                action: upsert
              - key: environment
                value: "production"
                action: upsert

          resourcedetection:
            detectors: [system]
            timeout: 5s

        exporters:
          ${lib.optionalString cfg.otel.enableLoggingExporter ''
          logging:
            verbosity: basic
            sampling_initial: 5
            sampling_thereafter: 200
          ''}

          ${lib.optionalString cfg.otel.enablePrometheusForwarding ''
          prometheusremotewrite:
            endpoint: "http://127.0.0.1:9090/api/v1/write"
            resource_to_telemetry_conversion:
              enabled: true
          ''}

          otlp:
            endpoint: "localhost:4317"
            tls:
              insecure: true

        service:
          extensions: []
          pipelines:
            traces:
              receivers: [otlp]
              processors: [memory_limiter, batch, attributes, resourcedetection]
              exporters: [otlp] ++ lib.optional cfg.otel.enableLoggingExporter "logging"

            metrics:
              receivers: [otlp, hostmetrics]
              processors: [memory_limiter, batch, attributes, resourcedetection]
              exporters: [otlp] ++ lib.optional cfg.otel.enablePrometheusForwarding "prometheusremotewrite" ++ lib.optional cfg.otel.enableLoggingExporter "logging"

            logs:
              receivers: [otlp, journald]
              processors: [memory_limiter, batch, attributes, resourcedetection]
              exporters: [otlp] ++ lib.optional cfg.otel.enableLoggingExporter "logging"

          telemetry:
            logs:
              level: info
            metrics:
              address: 0.0.0.0:8888
      '';
    };

    systemd.services.opentelemetry-collector = {
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

        # Hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadOnlyPaths = [ "/nix/store" "/proc" "/sys" ];
        CapabilityBoundingSet = "";
        AmbientCapabilities = "";
      };
    };

    # Expose OTel metrics endpoint
    networking.firewall.allowedTCPPorts = [ 8888 ];

    # Add OTel to Prometheus scrape targets
    services.prometheus.scrapeConfigs = [
      {
        job_name = "otelcol";
        static_configs = [
          {
            targets = [ "127.0.0.1:8888" ];
            labels = {
              host = hostName;
            };
          }
        ];
        scrape_interval = "15s";
      }
    ];
  };
}
