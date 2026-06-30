# hosts/laptop.nix
#
# Host-specific configuration for the "prague" laptop.
# Only configuration that differs per-host lives here.
#
# Pinned (never auto-discovered) — imported by configuration.nix
#
{ config, gitlabUrl, hostName, lib, pkgs, ... }:
{
  config = {
    ###########################################################
    # HOST IDENTITY
    ###########################################################
    networking.hostName = hostName;

    ###########################################################
    # SOPS — Host secrets
    ###########################################################
    sops = lib.mkIf config.ivali.secrets.enable {
      defaultSopsFile = ../secrets/tailscale.yaml;
      secrets = {
        tailscale_authkey = {
          sopsFile = ../secrets/tailscale.yaml;
        };
        grafana_secret_key = {
          sopsFile = ../secrets/tailscale.yaml;
        };
        gitlab-runner-token = {
          sopsFile = ../secrets/gitlab-runner.yaml;
        };
      };
    };

    ###########################################################
    # GITLAB RUNNER — Self-hosted CI
    ###########################################################
    fleet.gitlabRunner = lib.mkIf config.ivali.secrets.enable {
      enable = true;
      tokenFile = config.sops.secrets.gitlab-runner-token.path;
      tags = [ "nixos" "prague" "self-hosted" ];
      concurrent = 1;
    };

    ###########################################################
    # ZERO-TRUST NETWORKING
    ###########################################################
    ivali.tailscale = {
      enable = true;
      authKeyFile =
        lib.mkIf config.ivali.secrets.enable
          config.sops.secrets.tailscale_authkey.path;
      tags = [ "tag:admin" ];
      advertiseExitNode = true;
      acceptDns = false;
      acceptRoutes = false;
      tailnetDomain = "codlet-trench.ts.net";
    };

    ###########################################################
    # SSH — Shellfish access over Tailscale
    ###########################################################
    ivali.ssh = {
      enable = true;
      allowedUsers = [ "ivali" ];
      authorizedKeys = [
        # "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCnLKiK4YHXCXTgVdStJZanUuZeKoc8uYBbRiNVTzS68uGCklMVmlrExpLE7e58hGP7JJhYvpCB27ysf7xoU41lNVdj6ZUXtNbBMxsraA3LctBVcBVaAuZd0qntzrcicvKKzDYP+O1PA293GU6xSXIWxFo+n+1GSYGZXreFZai0XlQidrHcobRb5YKD5gTU7DMeuRRvajt6KyKo10dzVDpFJsqDwCjY2NtIXJdhfpmXa0kWTg6XywyHUBvQE+o71UR55rAvlWpUWXnA09Pq3OgnyMYFJw0nF8093KU4KWqIyRPTEhCxxjiPn2xMlBiS//lXgmcLasXrJPJu+zZHpGFeeOUpnkgvFnpRPKyoMzlGeb4bA77QxuivEKwtIGQBO0xSWdINDw5eZ6SO4kEkFn+ShqxMpSop1nVo5HvQwxL5n5FBbSTXMtMjwwFhiN/JXUQllGKGF77LHX14se5qxUoekO8h/H1JA/snLQSOkbP9j75I09n6aZy4OUDBSO480xDiXQbUYrvVkizSb0UyrRWYUec7qTO9MTyGqBOmAVArk6GfvnpDSfBeGdTKgfjImR2j021ktb1wN3OTGHL5RwnSJoEcTesv3HI+6Q7XGnuZ24guIirqLkpI/wJQbYcpaWS7niee9wAZxt81iBe+y9wp8YgpS3liahTWhYaTy7gKsw== ShellFish@iPhone-03062026"
      ];
      tailscaleOnly = true;
    };
  };
}
