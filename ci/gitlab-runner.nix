{ config, gitlabUrl, lib, pkgs, ... }:

let
  cfg = config.ivali.gitlabRunner;
  runnerHealth = pkgs.writeShellApplication {
    name = "gitlab-runner-health";
    runtimeInputs = [ pkgs.curl pkgs.gitlab-runner pkgs.systemd ];
    text = ''
      set -euo pipefail
      systemctl is-active --quiet gitlab-runner.service
      systemctl is-active --quiet docker.service
      gitlab-runner verify --delete >/dev/null
    '';
  };
in
{
  options.ivali.gitlabRunner = {
    enable = lib.mkEnableOption "self-hosted GitLab Runner";
    tokenFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/secrets/gitlab-runner-token";
      description = "File containing the GitLab Runner authentication token.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets.gitlab-runner-token = { };

    services.gitlab-runner = {
      enable = true;
      services.nix-shell = {
        authenticationTokenConfigFile = cfg.tokenFile;
        executor = "shell";
        tagList = [ "nixos" "laptop" "flakes" ];
      };
    };

    systemd.services.gitlab-runner-health = {
      description = "Health check for native GitLab Runner";
      after = [ "gitlab-runner.service" "docker.service" "network-online.target" ];
      wants = [ "network-online.target" ];
      onFailure = [ "gitlab-runner-rollback.service" ];
      serviceConfig.Type = "oneshot";
      script = "${runnerHealth}/bin/gitlab-runner-health";
    };

    systemd.timers.gitlab-runner-health = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5m";
        OnUnitActiveSec = "10m";
        Unit = "gitlab-runner-health.service";
      };
    };

    systemd.services.gitlab-runner-rollback = {
      description = "Rollback NixOS generation after failed GitLab Runner health check";
      serviceConfig = {
        Type = "oneshot";
        StartLimitBurst = 2;
        StartLimitIntervalSec = 3600;
      };
      path = [ pkgs.nixos-rebuild pkgs.systemd ];
      script = ''
        set -euo pipefail
        echo "GitLab Runner health failed for ${gitlabUrl}; rolling back to previous NixOS generation."
        nixos-rebuild switch --rollback
        systemctl restart gitlab-runner.service
      '';
    };
  };
}
