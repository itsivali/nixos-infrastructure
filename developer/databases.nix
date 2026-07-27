##############################################################################
#
# Local Development Databases
#
# Purpose
# -------
# Enable local PostgreSQL and Valkey (Redis-compatible) services for
# development. Includes CLI tools for database interaction.
#
# Ownership
# ---------
# options.ivali.dev.databases
# Delegates to services/postgres/ and services/redis/ for the actual
# service configuration.
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.dev.databases;
in
{
  options.ivali.dev.databases = {
    enable = lib.mkEnableOption "local development databases (PostgreSQL + Valkey)";
  };

  config = lib.mkIf cfg.enable {
    # Enable PostgreSQL
    ivali.services.postgres.enable = true;

    # Enable Valkey (Redis-compatible in-memory store)
    ivali.services.valkey.enable = true;

    # Database CLI tools
    environment.systemPackages = with pkgs; [
      postgresql
      pgcli
      valkey
    ];
  };
}
