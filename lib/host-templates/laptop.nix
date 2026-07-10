##############################################################################
#
# Laptop Host Template
#
# A proper NixOS module that reads hostSpec from specialArgs.
# Generates complete laptop configuration from declarative host spec.
#
##############################################################################

{ config, lib, pkgs, hostSpec, ... }:

let
  hostName = hostSpec.hostName;
  userName = hostSpec.userName;
  tags = hostSpec.tags or [];
  tailnetDomain = hostSpec.tailnetDomain or null;
  gitlabRunnerTags = hostSpec.gitlabRunnerTags or [];
  sshAuthorizedKeys = hostSpec.sshAuthorizedKeys or [];
  sopsKeyPath = hostSpec.sopsKeyPath or "/home/${userName}/.config/sops/age/keys.txt";
  features = hostSpec.features or {};
  repoPath = hostSpec.repoPath or "/home/${userName}/nixos-infrastructure";
  extraConfig = hostSpec.config or {};

  hasSecrets = features.secrets or false;
  hasGitLabRunner = features.gitlabRunner or false;
  hasBot = features.bot or false;
  hasTailscale = features.tailscale or false;
  hasTailscaleExitNode = features.tailscaleExitNode or true;
  hasSSH = features.ssh or false;
  hasBitwarden = features.bitwarden or false;

  tailscaleTags = tags
    ++ lib.optional (hasTailscaleExitNode && !(builtins.elem "tag:exit-node" tags)) "tag:exit-node";

in
{
  # Merge per-host extra config (defined in hosts/hosts.nix or host-specific files)
  imports = lib.optional (extraConfig != {}) { config = extraConfig; };

  ############################################################################
  # SOPS SECRETS DEFINITIONS
  ############################################################################
  sops = lib.mkIf hasSecrets {
    defaultSopsFile = ../../secrets/tailscale.yaml;
    secrets = {
      tailscale_authkey = { sopsFile = ../../secrets/tailscale.yaml; };
      grafana_secret_key = { sopsFile = ../../secrets/tailscale.yaml; };
      gitlab-runner-token = { sopsFile = ../../secrets/gitlab-runner.yaml; };
      telegram_bot_token = { sopsFile = ../../secrets/telegram.yaml; };
      telegram_chat_id = { sopsFile = ../../secrets/telegram.yaml; };
      notify_email = { sopsFile = ../../secrets/telegram.yaml; };
      gitlab_token = { sopsFile = ../../secrets/gitlab.yaml; };
    } // lib.optionalAttrs hasBitwarden {
      bitwarden_clientid = {
        sopsFile = ../../secrets/bitwarden.yaml;
        owner = userName;
        mode = "0400";
      };
      bitwarden_clientsecret = {
        sopsFile = ../../secrets/bitwarden.yaml;
        owner = userName;
        mode = "0400";
      };
      bitwarden_password = {
        sopsFile = ../../secrets/bitwarden.yaml;
        owner = userName;
        mode = "0400";
      };
    };
  };

  ############################################################################
  # SYSTEM IDENTITY
  ############################################################################
  networking.hostName = hostName;

  ############################################################################
  # SUDO CONFIGURATION
  ############################################################################
  security.sudo.extraRules =
    lib.optionals hasGitLabRunner [
      {
        users = [ "gitlab-runner" ];
        commands = [
          {
            command = "/run/current-system/sw/bin/systemctl";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ] ++ [
      {
        users = [ userName ];
        commands = [
          {
            command = "ALL";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ] ++ (extraConfig.security.sudo.extraRules or []);

  ############################################################################
  # GIT CONFIGURATION
  ############################################################################
  environment.etc."gitconfig".text = ''
    [safe]
      directory = ${repoPath}
  '';

  ############################################################################
  # SOPS SECRETS ENABLE
  ############################################################################
  ivali.secrets = {
    enable = lib.mkDefault hasSecrets;
    rotation = {
      enable = lib.mkDefault hasSecrets;
      keyPath = lib.mkDefault sopsKeyPath;
    };
  };

  ############################################################################
  # GITLAB RUNNER
  ############################################################################
  fleet.gitlabRunner = lib.mkIf (hasGitLabRunner && hasSecrets) {
    enable = true;
    tokenFile = config.sops.secrets.gitlab-runner-token.path;
    tags = gitlabRunnerTags;
    concurrent = 1;
  };

  ############################################################################
  # TELEGRAM BOT
  ############################################################################
  fleet.bot = lib.mkIf (hasBot && hasSecrets) {
    enable = true;
    gitlabUrl = config.fleet.gitops.repo or "https://gitlab.com/willisivali/nixos-infrastructure";
    defaultUser = userName;
  };

  ############################################################################
  # TAILSCALE
  ############################################################################
  ivali.tailscale = lib.mkIf hasTailscale {
    enable = true;
    authKeyFile = lib.mkIf hasSecrets config.sops.secrets.tailscale_authkey.path;
    tags = tailscaleTags;
    advertiseExitNode = hasTailscaleExitNode;
    acceptDns = false;
    acceptRoutes = false;
    tailnetDomain = tailnetDomain;
  };

  ############################################################################
  # SSH
  ############################################################################
  ivali.ssh = lib.mkIf hasSSH {
    enable = true;
    allowedUsers = [ userName ];
    authorizedKeys = sshAuthorizedKeys;
    tailscaleOnly = true;
  };

  ############################################################################
  # OBSERVABILITY
  ############################################################################
  ivali.observability = lib.mkMerge [
    {
      enable = true;
      exporters.enable = true;
      alertmanager.enable = true;
      otel.enable = true;
    }
    (lib.mkIf hasSecrets {
      alertmanager = {
        telegramBotTokenFile = config.sops.secrets.telegram_bot_token.path;
        telegramChatIdFile = config.sops.secrets.telegram_chat_id.path;
      };
    })
  ];

  ############################################################################
  # WEB SERVER (reverse proxy for observability)
  ############################################################################
  ivali.services.nginx.enable = true;

  ############################################################################
  # SECURITY SCANNING
  ############################################################################
  ivali.security.scanning.enable = true;
}
