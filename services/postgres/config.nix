##############################################################################
#
# PostgreSQL Configuration
#
# Purpose
# -------
# Relational database for local services.
#
# Ownership
# ---------
# services.postgresql, services.postgresqlBackup
#
# Responsibilities
# ----------------
# - Database for Grafana (if using PostgreSQL backend)
# - Database for local applications
# - Backup and maintenance
#
##############################################################################

{ config, lib, ... }:

let
  cfg = config.ivali.services.postgres;
in
{
  config = lib.mkIf cfg.enable {
    services.postgresql = {
      enable = true;

      settings = {
        port = cfg.port;
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
