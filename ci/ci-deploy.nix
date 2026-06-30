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
        TimeoutStartSec = "300s";
        StandardOutput = "journal";
        StandardError = "journal";
        SyslogIdentifier = "ci-deploy";

        NoNewPrivileges = true;
        PrivateTmp = true;
      };
    };
  };
}
