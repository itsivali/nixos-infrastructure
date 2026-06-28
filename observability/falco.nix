##############################################################################
#
# Falco
#
# Purpose
# -------
# Runtime security detection with Falco.
#
# Ownership
# ---------
# systemd.services.falco
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.observability;
in
{
  systemd.services.falco = lib.mkIf cfg.falco.enable {
    description = "Falco runtime security detection";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.falco}/bin/falco --modern-bpf";
      Restart = "always";
      RestartSec = "10s";
    };
  };
}
