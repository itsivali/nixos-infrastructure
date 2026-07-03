##############################################################################
#
# Redis
#
# Purpose
# -------
# In-memory cache and message broker.
#
# Ownership
# ---------
# services.redis
#
# Responsibilities
# ----------------
# - Caching for local applications
# - Session storage
# - Rate limiting
#
# Usage
# -----
# ivali.services.redis.enable = true;
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.services.redis;
in
{
  options.ivali.services.redis = {
    enable = lib.mkEnableOption "Redis cache";

    port = lib.mkOption {
      type = lib.types.port;
      default = 6379;
      description = "Redis listening port";
    };

    maxMemory = lib.mkOption {
      type = lib.types.str;
      default = "256mb";
      description = "Maximum memory usage";
    };
  };

  config = lib.mkIf cfg.enable {
    services.redis = {
      servers."default" = {
        enable = true;
        port = cfg.port;
        bind = "127.0.0.1";
        settings = {
          maxmemory = cfg.maxMemory;
          maxmemory-policy = "allkeys-lru";
        };
      };
    };
  };
}
