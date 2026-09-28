##############################################################################
#
# Docker
#
# Purpose
# -------
# Docker container runtime configuration.
#
# Ownership
# ---------
# virtualisation.docker
#
# Does NOT Own
# ------------
# - Shell defaults (developer/shell.nix)
# - Language toolchains (developer/languages.nix)
# - Podman or other runtimes (N/A)
#
##############################################################################

{ config, lib, ... }:

let
  cfg = config.ivali.docker;
in
{
  options.ivali.docker = {
    enable = lib.mkEnableOption "Docker container runtime";
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker = {
      enable = true;
      enableOnBoot = true;
      # Disable Docker's iptables integration — the host firewall uses
      # nftables exclusively and Docker's iptables bridge rules conflict
      # with the nftables PREROUTING chain.
      extraOptions = "--iptables=false --ip6tables=false --bridge=none";
    };
  };
}
