# hosts/laptop.nix
{ config, gitlabUrl, hostName, lib, pkgs, ... }:

{
  ###########################################################
  # INSTALL-TIME SECRETS
  ###########################################################

  options.ivali.secrets.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
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
      age.keyFile = "/var/lib/sops-nix/key.txt";
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

      tag = "tag:admin";
      advertiseExitNode = true;
      acceptDns = false;
      acceptRoutes = false;
      tailnetDomain = "codlet-trench.ts.net";
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
