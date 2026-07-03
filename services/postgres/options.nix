##############################################################################
#
# PostgreSQL Options
#
# Purpose
# -------
# Option declarations for the PostgreSQL module.
#
# Ownership
# ---------
# options.ivali.services.postgres
#
##############################################################################

{ lib, ... }:

{
  options.ivali.services.postgres = {
    enable = lib.mkEnableOption "PostgreSQL database";

    port = lib.mkOption {
      type = lib.types.port;
      default = 5432;
      description = "PostgreSQL listening port";
    };
  };
}
