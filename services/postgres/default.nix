##############################################################################
#
# PostgreSQL
#
# Purpose
# -------
# Relational database for local services.
#
# Ownership
# ---------
# services.postgresql
#
# Responsibilities
# ----------------
# - Database for Grafana (if using PostgreSQL backend)
# - Database for local applications
# - Backup and maintenance
#
# Usage
# -----
# ivali.services.postgres.enable = true;
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.services.postgres;
in
{
  options.ivali.services.postgres = {
    enable = lib.mkEnableOption "PostgreSQL database";

    port = lib.mkOption {
      type = lib.types.port;
      default = 5432;
      description = "PostgreSQL listening port";
    };
  };

  config = lib.mkIf cfg.enable {
    services.postgresql = {
      enable = true;
      port = cfg.port;

      settings = {
        shared_buffers = "256MB";
        effective_cache_size = "768MB";
        work_mem = "4MB";
        maintenance_work_mem = "128MB";
      };

      ensureDatabases = [ "grafana" ];
      ensureUsers = [
        {
          name = "grafana";
          ensureDBOwnership = true;
        }
      ];
    };

    # Backup configuration
    services.postgresqlBackup = {
      enable = true;
      databases = [ "grafana" ];
    };
  };
}
