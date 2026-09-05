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
  tags = hostSpec.tags or [ ];
  tailnetDomain = hostSpec.tailnetDomain or null;
  gitlabRunnerTags = hostSpec.gitlabRunnerTags or [ ];
  sshAuthorizedKeys = hostSpec.sshAuthorizedKeys or [ ];
  sopsKeyPath = hostSpec.sopsKeyPath or "/home/${userName}/.config/sops/age/keys.txt";
  features = hostSpec.features or { };
  repoPath = hostSpec.repoPath or "/home/${userName}/nixos-infrastructure";
  extraConfig = hostSpec.config or { };

  hasSecrets = features.secrets or false;
  hasGitLabRunner = features.gitlabRunner or false;
  hasTailscale = features.tailscale or false;
  hasTailscaleExitNode = features.tailscaleExitNode or true;
  hasSSH = features.ssh or false;
  hasBitwarden = features.bitwarden or false;

  tailscaleTags = tags
    ++ lib.optional (hasTailscaleExitNode && !(builtins.elem "tag:exit-node" tags)) "tag:exit-node";

in
{
  # Merge per-host extra config (defined in hosts/<name>.nix or host-specific files)
  imports = lib.optional (extraConfig != { }) { config = extraConfig; };

  ############################################################################
  # SOPS SECRETS DEFINITIONS
  ############################################################################
  sops = lib.mkIf hasSecrets {
    defaultSopsFile = ../../secrets/tailscale.yaml;
    secrets = {
      tailscale_authkey = { sopsFile = ../../secrets/tailscale.yaml; };
      grafana_secret_key = { sopsFile = ../../secrets/tailscale.yaml; };
      gitlab-runner-token = { sopsFile = ../../secrets/gitlab-runner.yaml; };
      notify_email = { sopsFile = ../../secrets/notifications.yaml; };
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
            command = "/run/current-system/sw/bin/systemctl start ci-deploy.service";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/systemctl start ci-notify.service";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ] ++ [
      # Passwordless for a few frequent, low-risk admin commands only.
      {
        users = [ userName ];
        commands = [
          { command = "/run/current-system/sw/bin/nixos-rebuild"; options = [ "NOPASSWD" ]; }
          { command = "/run/current-system/sw/bin/systemctl start gitops-reconciler*"; options = [ "NOPASSWD" ]; }
        ];
      }
      # General sudo still requires a password.
      {
        users = [ userName ];
        commands = [{ command = "ALL"; }];
      }
    ] ++ (extraConfig.security.sudo.extraRules or [ ]);

  ############################################################################
  # GIT CONFIGURATION
  ############################################################################
  environment.etc."gitconfig".text = lib.mkDefault ''
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
  # GO BINARY CACHE
  # Caches ivali / bw-tui (and any future Go tool) in a local
  # binary cache so switching generations restores them in seconds instead
  # of recompiling from scratch.
  ############################################################################
  goBinaryCache.enable = true;

  ############################################################################
  # FHS ENVIRONMENT CACHE
  # Caches FHS environment builds (kilocode, antigravity, etc.) in the
  # attic binary cache so they are restored in seconds instead of being
  # rebuilt from scratch. FHS environments are expensive to build because
  # they create entire Linux filesystem hierarchies.
  ############################################################################
  fhsCache = lib.mkIf (config.ivali.kilocode.enable || config.ivali.antigravity.enable) {
    enable = true;
    packages = lib.optionals config.ivali.kilocode.enable [
      config.ivali.kilocode.package
    ] ++ lib.optionals config.ivali.antigravity.enable [
      config.ivali.antigravity.package
    ];
  };

  ############################################################################
  # BINARY CACHE (attic)
  # Dormant by design: the attic signing key has not been provisioned yet, so
  # `publicKey` stays empty. The consumer module is fail-safe — it only wires
  # the cache into Nix when a verifiable key is set. Enable once a real cache
  # (with a signing key) exists; also re-introduce the attic *server* half in
  # `cache/default.nix` (previous `atticd serve` invocation was invalid).
  ############################################################################
  fleet.cache = {
    enable = false;
    url = "http://localhost:8080";
    publicKey = "";
  };

  ############################################################################
  # GITLAB RUNNER
  ############################################################################
  fleet.gitlabRunner = lib.mkIf (hasGitLabRunner && hasSecrets) {
    enable = true;
    tokenFile = config.sops.secrets.gitlab-runner-token.path;
    tags = gitlabRunnerTags;
    concurrent = 1;
    gitopsRepo = config.fleet.gitops.repo;
    gitopsBranch = config.fleet.gitops.branch;
  };

  ############################################################################
  # GITOPS RECONCILER
  # Automatically pulls from GitLab main branch every 15 minutes
  # and runs nixos-rebuild switch to apply changes.
  ############################################################################
  fleet.gitops = {
    repo = "https://gitlab.com/willisivali/nixos-infrastructure";
    branch = "main";
  };

  fleet.gitopsReconciler = {
    enable = true;
    schedule = "*:0/15";
    canary = false;
  };

  ############################################################################
  # DEPLOYMENT HEALTH
  ############################################################################
  fleet.deploymentHealth = lib.mkIf (hasGitLabRunner && hasSecrets) {
    enable = true;
    gitopsRepo = config.fleet.gitops.repo;
    gitopsBranch = config.fleet.gitops.branch;
  };

  ############################################################################
  # TAILSCALE
  ############################################################################
  ivali.tailscale = lib.mkIf hasTailscale {
    enable = true;
    authKeyFile = lib.mkIf hasSecrets config.sops.secrets.tailscale_authkey.path;
    tags = tailscaleTags;
    advertiseExitNode = hasTailscaleExitNode;
    # acceptDns = true: let Tailscale manage MagicDNS split-DNS.
    # Registers 100.100.100.100 as the resolver for the tailnet domain
    # via systemd-resolved, so <host>.<tailnetDomain> resolves without
    # overriding the system's global DNS.
    acceptDns = true;
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
    # Session hardening defaults
    maxAuthTries = 3;
    clientAliveInterval = 300;
    clientAliveCountMax = 3;
    loginGraceTime = 60;
  };

  ############################################################################
  # OBSERVABILITY
  ############################################################################
  ivali.observability = {
    enable = lib.mkDefault true;
    exporters.enable = lib.mkDefault true;
    alertmanager.enable = lib.mkDefault true;
    otel.enable = lib.mkDefault true;
  };

  ############################################################################
  # WEB SERVER (reverse proxy for observability)
  ############################################################################
  ivali.services.nginx.enable = true;

  ############################################################################
  # SECURITY SCANNING
  ############################################################################
  ivali.security.scanning.enable = true;

  ############################################################################
  # FAIL2BAN (brute-force protection)
  ############################################################################
  ivali.security.fail2ban.enable = true;

  ############################################################################
  # AI CODING AGENTS
  ############################################################################
}
