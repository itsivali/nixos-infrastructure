##############################################################################
#
# Tuscany — Secondary Laptop
#
# Purpose
# -------
# Host spec for tuscany: secondary laptop. Copy this file and customize
# for a new host. Run `ivali bootstrap host tuscany` to generate the
# hardware configuration.
#
# Adding a new host:
#   1. Copy this file (or create from scratch)
#   2. Customize hostName, userName, features, config
#   3. Run `ivali bootstrap host <name>` to generate hardware config
#   4. Commit and push
#
##############################################################################

{ lib, ... }:

{
  hostName = "tuscany";
  userName = "ivali";
  repoPath = "/home/ivali/nixos-infrastructure";
  tags = [ "tag:personal" ];
  tailnetDomain = "codlet-trench.ts.net";
  gitlabRunnerTags = [ "nixos" "tuscany" "self-hosted" ];
  sshAuthorizedKeys = [ ];
  sopsKeyPath = "/home/ivali/.config/sops/age/keys.txt";
  features = {
    secrets = true;
    bitwarden = true;
    gitlabRunner = true;
    bot = true;
    tailscale = true;
    tailscaleExitNode = true;
    ssh = true;
  };
  config = {
    ivali.desktop.gnome.enable = true;
    fleet.gitopsReconciler.enable = true;
    fleet.deploymentHealth.enable = true;
    fleet.deploymentHealth.enableRollback = true;
    ivali.dev.databases.enable = true;
    ivali.cloud.enable = true;
    ivali.desktop.clipboard.enable = true;
  };
}
