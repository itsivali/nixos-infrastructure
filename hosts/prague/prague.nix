##############################################################################
#
# Host Configuration — prague
#
# Purpose
# -------
# Host-specific configuration for the prague laptop.
# This file contains configuration that differs per-host.
#
# Ownership
# ---------
# This file is managed by ivali bootstrap. For structural changes,
# modify lib/host-templates/laptop.nix and regenerate.
#
##############################################################################

{ config, lib, pkgs, hostSpec, hostName, defaultUsername, gitlabUrl, ... }:

let
  userName = hostSpec.userName or defaultUsername;
in
{
  ############################################################################
  # SYSTEM IDENTITY
  ############################################################################
  networking.hostName = hostName;

  ############################################################################
  # SUDO CONFIGURATION
  ############################################################################
  security.sudo.extraRules = [
    # GitLab Runner needs systemctl for deployments
    {
      users = [ "gitlab-runner" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/systemctl";
          options = [ "NOPASSWD" ];
        }
      ];
    }
    # Primary user gets full sudo
    {
      users = [ userName ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  ############################################################################
  # GIT CONFIGURATION (system-wide for root/CI access)
  ############################################################################
  environment.etc."gitconfig".text = ''
    [safe]
      directory = /home/ivali/nixos-infrastructure
  '';

  ############################################################################
  # SOPS SECRETS
  ############################################################################
  config.ivali.secrets.enable = true;

  sops = {
    defaultSopsFile = ../../secrets/tailscale.yaml;
    secrets = {
      tailscale_authkey = {
        sopsFile = ../../secrets/tailscale.yaml;
      };
      grafana_secret_key = {
        sopsFile = ../../secrets/tailscale.yaml;
      };
      gitlab-runner-token = {
        sopsFile = ../../secrets/gitlab-runner.yaml;
      };
      telegram_bot_token = {
        sopsFile = ../../secrets/telegram.yaml;
      };
      telegram_chat_id = {
        sopsFile = ../../secrets/telegram.yaml;
      };
      notify_email = {
        sopsFile = ../../secrets/telegram.yaml;
      };
      gitlab_token = {
        sopsFile = ../../secrets/gitlab.yaml;
      };
      # Host-specific secrets
      ssh_authorized_keys = {
        sopsFile = ../../secrets/hosts/prague.yaml;
      };
    };
  };

  ############################################################################
  # GITLAB RUNNER
  ############################################################################
  fleet.gitlabRunner = {
    enable = true;
    tokenFile = config.sops.secrets.gitlab-runner-token.path;
    tags = [ "nixos" "prague" "self-hosted" ];
    concurrent = 1;
  };

  ############################################################################
  # TELEGRAM BOT CONTROL PLANE
  ############################################################################
  fleet.bot = {
    enable = true;
    gitlabUrl = gitlabUrl;
    defaultUser = userName;
  };

  ############################################################################
  # TAILSCALE ZERO-TRUST NETWORKING
  ############################################################################
  ivali.tailscale = {
    enable = true;
    authKeyFile = config.sops.secrets.tailscale_authkey.path;
    tags = [ "tag:admin" ];
    advertiseExitNode = true;
    acceptDns = false;
    acceptRoutes = false;
    tailnetDomain = "codlet-trench.ts.net";
  };

  ############################################################################
  # SSH DAEMON (Tailscale-only access)
  ############################################################################
  ivali.ssh = {
    enable = true;
    allowedUsers = [ userName ];
    authorizedKeys = [
      # Key loaded from SOPS secret at runtime
    ];
    tailscaleOnly = true;
  };
}