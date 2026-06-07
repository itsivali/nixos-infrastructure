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

      # Automatically enroll into the tailnet using the
      # SOPS-managed auth key once secrets are enabled.
      authKeyFile =
        lib.mkIf config.ivali.secrets.enable
          config.sops.secrets.tailscale_authkey.path;

      # Matches your ACL model.
      tag = "tag:admin";

      # Prague acts as an exit node.
      advertiseExitNode = true;

      # Prevent Tailscale from taking over DNS.
      acceptDns = false;

      # Prevent automatic route acceptance.
      acceptRoutes = false;

      # Tailnet split-DNS domain.
      tailnetDomain = "codlet-trench.ts.net";

    };

    ###########################################################

    # NIX / GITOPS

    ###########################################################

    nix.settings.warn-dirty = false;

    system.autoUpgrade = {
      # Enable after hosts/hardware-configuration.nix has been committed and
      # pushed, so the remote flake matches the installed machine.
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
