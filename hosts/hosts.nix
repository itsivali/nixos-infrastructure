##############################################################################
#
# Host Registry
#
# Purpose
# -------
# Aggregator that auto-imports per-host spec files from this directory.
# Each host file (e.g. prague.nix, tuscany.nix) returns a simple attrset
# with the host's identity, features, and config overrides.
#
# Adding a new host:
#   1. Create hosts/<name>.nix with the host spec
#   2. Run `ivali bootstrap host <name>` to generate hardware config
#   3. Commit and push
#
# Host spec structure:
#   {
#     hostName      = "hostname";           # networking.hostName
#     userName      = "username";           # Home Manager user
#     repoPath      = "/home/user/repo";    # Path to this repo on the host
#     tags          = [ "tag:..." ];        # Tailscale ACL tags
#     tailnetDomain = "xxx.ts.net";         # Optional split DNS domain
#     gitlabRunnerTags = [ "nixos", "..." ]; # GitLab runner tags
#     sshAuthorizedKeys = [ "ssh-...", ... ]; # SSH public keys
#     sopsKeyPath     = "/home/user/.config/sops/age/keys.txt";
#     features = {
#       secrets         = true;
#       gitlabRunner    = true;
#       bot             = true;
#       tailscale       = true;
#       tailscaleExitNode = true;
#       ssh             = true;
#     };
#     config = { ... };                    # NixOS config overrides
#   };
#
##############################################################################

{ lib }:

let
  root = ./.;

  # Files to skip when scanning for host specs
  skipFiles = [
    "hosts.nix"
    "hardware-configuration.nix"
    "default.nix"
  ];

  entries = builtins.readDir root;

  hostFiles = builtins.filter
    (name:
      entries.${name} == "regular"
      && builtins.match ".*\\.nix" name != null
      && !(builtins.elem name skipFiles)
      && builtins.match "_.*" name == null
    )
    (builtins.attrNames entries);

  # Import each host file and build the registry attrset
  # Each file returns { hostname = { hostName, userName, ... }; }
  hostSpecs = builtins.listToAttrs (map
    (name:
      let spec = import (root + "/${name}") { inherit lib; };
      in {
        name = spec.hostName or (builtins.replaceStrings [ ".nix" ] [ "" ] name);
        value = spec;
      }
    )
    hostFiles);
in
hostSpecs
