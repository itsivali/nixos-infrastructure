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
  config = lib.mkIf cfg.otel.enable (
    let
      yamlFormat = pkgs.formats.yaml { };
      otelExporters = [ "otlp" ] ++ lib.optional cfg.otel.enableLoggingExporter "debug";
      otelMetricsExporters = [ "otlp" ] ++ lib.optional cfg.otel.enablePrometheusForwarding "prometheusremotewrite"
        ++ lib.optional cfg.otel.enableLoggingExporter "debug";
    in {
      environment.etc."otelcol/config.yaml" = {
        source = yamlFormat.generate "otelcol-config.yaml" {
          receivers = {
            otlp = {
              protocols = {
                grpc.endpoint = "0.0.0.0:4317";
                http.endpoint = "0.0.0.0:4318";
              };
            };
            hostmetrics = {
              collection_interval = "120s";
              scrapers = {
                cpu = { };
                memory = { };
                disk = { };
                filesystem = { };
                network = { };
                processes = { };
                system = { };
              };
            };
          };

          processors = {
            batch = {
              timeout = "5s";
              send_batch_size = 1024;
            };
            memory_limiter = {
              check_interval = "1s";
              limit_mib = 128;
              spike_limit_mib = 32;
            };
            attributes = {
              actions = [
                {
                  key = "host.name";
                  value = hostName;
                  action = "upsert";
                }
                {
                  key = "environment";
                  value = "production";
                  action = "upsert";
                }
              ];
            };
            resourcedetection = {
              detectors = [ "system" ];
              timeout = "5s";
            };
          };

          exporters = {
            otlp = {
              endpoint = "localhost:4317";
              tls.insecure = true;
            };
          } // lib.optionalAttrs cfg.otel.enableLoggingExporter {
            debug = {
              verbosity = "basic";
              sampling_initial = 5;
              sampling_thereafter = 200;
            };
          } // lib.optionalAttrs cfg.otel.enablePrometheusForwarding {
            prometheusremotewrite = {
              endpoint = "http://127.0.0.1:9090/api/v1/write";
              resource_to_telemetry_conversion.enabled = true;
            };
          };

          service = {
            extensions = [ ];
            pipelines = {
              traces = {
                receivers = [ "otlp" ];
                processors = [ "memory_limiter" "batch" "attributes" "resourcedetection" ];
                exporters = otelExporters;
              };
              metrics = {
                receivers = [ "otlp" "hostmetrics" ];
                processors = [ "memory_limiter" "batch" "attributes" "resourcedetection" ];
                exporters = otelMetricsExporters;
              };
              logs = {
                receivers = [ "otlp" ];
                processors = [ "memory_limiter" "batch" "attributes" "resourcedetection" ];
                exporters = otelExporters;
              };
            };
            telemetry = {
              logs.level = "info";
              metrics.readers = [
                {
                  pull = {
                    exporter = {
                      prometheus = {
                        host = "0.0.0.0";
                        port = 8888;
                      };
                    };
                  };
                }
              ];
            };
          };
        };
      };

    systemd.services.opentelemetry-collector = {
      description = "OpenTelemetry collector";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        ExecStart =
          "${pkgs.opentelemetry-collector-contrib}/bin/otelcol-contrib --config=/etc/otelcol/config.yaml";
        Restart = "always";
        RestartSec = "10s";

        # Hardening
        MemoryMax = "256M";
        MemoryHigh = "192M";
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
        scrape_interval = "60s";
      }
    ];
    });
}
