##############################################################################
#
# Valkey Options
#
# Purpose
# -------
# Option declarations for the Valkey (open-source Redis) module.
#
# Ownership
# ---------
# options.ivali.services.valkey
#
##############################################################################

{ lib, ... }:

{
  options.ivali.services.valkey = {
    enable = lib.mkEnableOption "Valkey (open-source Redis)";

    port = lib.mkOption {
      type = lib.types.port;
      default = 6379;
      description = "Valkey listening port";
    };

    bind = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Valkey bind address";
    };

    maxMemory = lib.mkOption {
      type = lib.types.str;
      default = "256mb";
      description = "Maximum memory usage";
    };

    maxMemoryPolicy = lib.mkOption {
      type = lib.types.str;
      default = "allkeys-lru";
      description = "Eviction policy when maxmemory is reached";
    };

    persistence = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable RDB persistence";
    };

    logLevel = lib.mkOption {
      type = lib.types.enum [ "debug" "verbose" "notice" "warning" ];
      default = "notice";
      description = "Valkey log level";
    };
  };
}
