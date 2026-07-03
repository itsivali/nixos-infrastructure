##############################################################################
#
# Nginx Options
#
# Purpose
# -------
# Option declarations for the Nginx module.
#
# Ownership
# ---------
# options.ivali.services.nginx
#
##############################################################################

{ lib, ... }:

{
  options.ivali.services.nginx = {
    enable = lib.mkEnableOption "Nginx web server";
  };
}
