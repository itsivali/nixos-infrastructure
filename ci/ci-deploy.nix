##############################################################################
#
# CI Deploy
#
# Purpose
# -------
# Defines a systemd service for CI-triggered NixOS deployments that applies
# system configuration changes from the local repository checkout.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Configure the ci-deploy oneshot systemd service
# - Provide nix, nixos-rebuild, and coreutils in the service PATH
# - Pass host name and repo directory as environment variables
# - Enforce hardening (NoNewPrivileges, PrivateTmp)
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.fleet.gitlabRunner;

  deployScript =
    if builtins.pathExists ../scripts/ci-deploy.sh then
      ../scripts/ci-deploy.sh
    else
      throw ''
        Missing:

          scripts/ci-deploy.sh
      '';
in
{
  config = lib.mkIf cfg.enable {
    systemd.services.ci-deploy = {
      description = "CI-Triggered NixOS Deployment";

      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      path = with pkgs; [
        bash
        coreutils
        nix
        nixos-rebuild
        util-linux
      ];

      environment = {
        HOST_NAME = config.networking.hostName;
        REPO_DIR = "/home/ivali/nixos-infrastructure";
      };

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        Group = "root";
        ExecStart = deployScript;
        # Full gate flow (flake check → eval → build → switch → health gate)
        # can exceed 5 minutes on this 2-core box, especially for uncached
        # builds. One hour gives the deployment room to complete while still
        # failing fast on a hung build.
        TimeoutStartSec = "3600s";
        StandardOutput = "journal";
        StandardError = "journal";
        SyslogIdentifier = "ci-deploy";

        NoNewPrivileges = true;
        PrivateTmp = true;
      };
    };
  };
}
