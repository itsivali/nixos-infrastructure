##############################################################################
#
# Host Registry
#
# Purpose
# -------
# Central registry of all known hosts. Each host defines its identity
# and feature flags. The flake.nix imports this and generates
# nixosConfigurations for each host.
#
# Adding a new host:
#   1. Add an entry here
#   2. Run `ivali bootstrap host <name>` to generate hardware config
#   3. Commit and push
#
# Structure:
#   <name> = {
#     hostName      = "hostname";           # networking.hostName
#     userName      = "username";           # Home Manager user
#     repoPath      = "/home/user/repo";    # Path to this repo on the host
#     tags          = [ "tag:..." ];        # Tailscale ACL tags
#     tailnetDomain = "xxx.ts.net";         # Optional split DNS domain
#     gitlabRunnerTags = [ "nixos", "..." ]; # GitLab runner tags
#     sshAuthorizedKeys = [ "ssh-...", ... ]; # SSH public keys
#     features = {
#       secrets         = true;             # Enable SOPS secrets
#       gitlabRunner    = true;             # Enable self-hosted GitLab runner
#       bot             = true;             # Enable Telegram bot
#       tailscale       = true;             # Enable Tailscale
#       tailscaleExitNode = true;           # Advertise as exit node
#       ssh             = true;             # Enable SSH daemon
#     #     # };
#     config = { ... };                    # Additional NixOS config overrides
#   };
#
##############################################################################

{ lib, ... }:

{
  ############################################################################
  # DEFAULT HOST TEMPLATE
  # Used by `ivali bootstrap host` as the base for new hosts
  ############################################################################
  default = {
    hostName = "laptop";
    userName = "user";
    repoPath = "/home/user/nixos-infrastructure";
    tags = [ "tag:personal" ];
    tailnetDomain = null;
    gitlabRunnerTags = [ "nixos" "self-hosted" ];
    sshAuthorizedKeys = [];
    features = {
      secrets = true;
      gitlabRunner = true;
      bot = true;
      tailscale = true;
      tailscaleExitNode = true;
      ssh = true;
    };
    config = {};
  };

  ############################################################################
  # EXISTING HOST: prague
  # Migrated from hosts/laptop.nix
  ############################################################################
  prague = {
    hostName = "prague";
    userName = "ivali";
    repoPath = "/home/ivali/nixos-infrastructure";
    tags = [ "tag:admin" ];
    tailnetDomain = "codlet-trench.ts.net";
    gitlabRunnerTags = [ "nixos" "prague" "self-hosted" ];
    sshAuthorizedKeys = [
      # Key loaded from SOPS secret at runtime
    ];
    features = {
      secrets = true;
      gitlabRunner = true;
      bot = true;
      tailscale = true;
      tailscaleExitNode = true;
      ssh = true;
    };
    config = {
      # Git config for root/CI access
      environment.etc."gitconfig".text = ''
        [safe]
          directory = /home/ivali/nixos-infrastructure
      '';
    };
  };
}