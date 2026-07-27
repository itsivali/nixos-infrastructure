##############################################################################
#
# Test VM — Minimal Test Host
#
# Purpose
# -------
# Minimal host spec for testing ivali bootstrap host and NixOS VM tests.
# No services, no secrets, no Tailscale — SSH only.
#
##############################################################################

{ ... }:

{
  hostName = "testvm";
  userName = "testuser";
  repoPath = "/home/testuser/nixos-infrastructure";
  tags = [ "tag:test" ];
  tailnetDomain = null;
  gitlabRunnerTags = [ "nixos" "testvm" ];
  sshAuthorizedKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITESTKEY test@testvm" ];
  features = {
    secrets = false;
    gitlabRunner = false;
    bot = false;
    tailscale = false;
    tailscaleExitNode = false;
    ssh = true;
  };
  config = { };
}
