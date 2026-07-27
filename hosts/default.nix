##############################################################################
#
# Default Host Template
#
# Purpose
# -------
# Base host spec used by `ivali bootstrap host` for new machines.
# Provides sensible defaults that can be overridden per-host.
#
##############################################################################

{ lib, ... }:

{
  hostName = "laptop";
  userName = "user";
  repoPath = "/home/user/nixos-infrastructure";
  tags = [ "tag:personal" ];
  tailnetDomain = null;
  gitlabRunnerTags = [ "nixos" "self-hosted" ];
  sshAuthorizedKeys = [ ];
  sopsKeyPath = "/home/user/.config/sops/age/keys.txt";
  features = {
    secrets = true;
    gitlabRunner = true;
    bot = true;
    tailscale = true;
    tailscaleExitNode = true;
    ssh = true;
  };
  config = { };
}
