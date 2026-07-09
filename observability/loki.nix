##############################################################################
#
# Loki
#
# Purpose
# -------
# Local Loki log aggregation service.
#
# Ownership
# ---------
# services.loki
#
##############################################################################

{ config, lib, ... }:

let
  cfg = config.ivali.observability;
  lokiListenAddress = "127.0.0.1";
  lokiPort = 3100;
in
{
  services.loki = lib.mkIf cfg.loki.enable {
    enable = true;
    extraFlags = [ "-config.expand-env=true" ];
    configuration = {
      auth_enabled = false;
      server = {
        http_listen_address = lokiListenAddress;
        http_listen_port = lokiPort;
        grpc_listen_port = 0;
      };
      common = {
        path_prefix = "/var/lib/loki";
        storage.filesystem = {
          chunks_directory = "/var/lib/loki/chunks";
          rules_directory = "/var/lib/loki/rules";
        };
        replication_factor = 1;
        ring.kvstore.store = "inmemory";
      };
      schema_config.configs = [
        {
          from = "2024-01-01";
          store = "tsdb";
          object_store = "filesystem";
          schema = "v13";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }
      ];
      limits_config = {
        allow_structured_metadata = false;
        retention_period = "48h";
        ingestion_rate_mb = 4;
        ingestion_burst_size_mb = 8;
        max_streams_per_user = 0;
        max_global_streams_per_user = 0;
        max_line_size = "256KB";
      };
      compactor = {
        working_directory = "/var/lib/loki/compactor";
        retention_enabled = true;
        delete_request_store = "filesystem";
      };
      analytics.reporting_enabled = false;
    };
  };
}
