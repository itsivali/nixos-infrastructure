# hosts/laptop.nix
{ config, gitlabUrl, hostName, lib, pkgs, ... }:
{
  ###########################################################
  # INSTALL-TIME SECRETS
  ###########################################################
  options.ivali.secrets.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Enable SOPS-backed secrets. Leave disabled for a first install unless
      /var/lib/sops-nix/key.txt already contains the matching age private key.
    '';
  };

  config = {
    ###########################################################
    # HOST IDENTITY
    ###########################################################
    networking.hostName = hostName;

    ###########################################################
    # LOCALE
    ###########################################################
    i18n.defaultLocale = "en_US.UTF-8";

    ###########################################################
    # AMD GPU
    # Load amdgpu early in initrd so the display is available
    # as soon as the kernel hands off to systemd. Without this
    # the screen goes black after early boot messages.
    ###########################################################
    boot.initrd.kernelModules = [ "amdgpu" ];
    services.xserver.videoDrivers = [ "amdgpu" ];
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    ###########################################################
    # HOST PACKAGES
    ###########################################################
    environment.systemPackages =
      (import ../packages/system { inherit pkgs; })
      ++ [
        pkgs.btop
        pkgs.fastfetch
        pkgs.htop
        pkgs.iproute2
        pkgs.tailscale
      ];

    ###########################################################
    # SOPS
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
      };
    };

    ###########################################################
    # ZERO-TRUST NETWORKING
    ###########################################################
    ivali.tailscale = {
      enable = true;
      authKeyFile =
        lib.mkIf config.ivali.secrets.enable
          config.sops.secrets.tailscale_authkey.path;
      # tag:exit-node is appended automatically by the module
      # when advertiseExitNode = true
      tags = [ "tag:admin" ];
      advertiseExitNode = true;
      acceptDns = false;
      acceptRoutes = false;
      tailnetDomain = "codlet-trench.ts.net";
    };

    ###########################################################
    # SSH — Shellfish access over Tailscale
    # Connect from Shellfish: prague.codlet-trench.ts.net:22
    ###########################################################
    ivali.ssh = {
      enable = true;
      allowedUsers = [ "ivali" ];
      # Paste your Shellfish-generated public key below.
      # In Shellfish: Settings → SSH Keys → + → Copy Public Key
      authorizedKeys = [
        # "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCnLKiK4YHXCXTgVdStJZanUuZeKoc8uYBbRiNVTzS68uGCklMVmlrExpLE7e58hGP7JJhYvpCB27ysf7xoU41lNVdj6ZUXtNbBMxsraA3LctBVcBVaAuZd0qntzrcicvKKzDYP+O1PA293GU6xSXIWxFo+n+1GSYGZXreFZai0XlQidrHcobRb5YKD5gTU7DMeuRRvajt6KyKo10dzVDpFJsqDwCjY2NtIXJdhfpmXa0kWTg6XywyHUBvQE+o71UR55rAvlWpUWXnA09Pq3OgnyMYFJw0nF8093KU4KWqIyRPTEhCxxjiPn2xMlBiS//lXgmcLasXrJPJu+zZHpGFeeOUpnkgvFnpRPKyoMzlGeb4bA77QxuivEKwtIGQBO0xSWdINDw5eZ6SO4kEkFn+ShqxMpSop1nVo5HvQwxL5n5FBbSTXMtMjwwFhiN/JXUQllGKGF77LHX14se5qxUoekO8h/H1JA/snLQSOkbP9j75I09n6aZy4OUDBSO480xDiXQbUYrvVkizSb0UyrRWYUec7qTO9MTyGqBOmAVArk6GfvnpDSfBeGdTKgfjImR2j021ktb1wN3OTGHL5RwnSJoEcTesv3HI+6Q7XGnuZ24guIirqLkpI/wJQbYcpaWS7niee9wAZxt81iBe+y9wp8YgpS3liahTWhYaTy7gKsw== ShellFish@iPhone-03062026"
      ];
      # true = port 22 only reachable through Tailscale (tailscale0 interface)
      tailscaleOnly = true;
    };

    ###########################################################
    # NIX / GITOPS
    ###########################################################
    nix.settings.warn-dirty = false;
    system.autoUpgrade = {
      enable = false;
      flake = "git+${gitlabUrl}#${hostName}";
      flags = [
        "--refresh"
        "--print-build-logs"
      ];
      dates = "04:30";
      randomizedDelaySec = "45min";
      allowReboot = false;
    };
  };
}
