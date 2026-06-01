{ config, gitlabUrl, hostName, pkgs, ... }:

{

  ###########################################################
  # HOST IDENTITY
  ###########################################################

  networking.hostName = hostName;

  ###########################################################
  # HARDWARE BOUNDARY
  ###########################################################

  # The installer copies /etc/nixos/hardware-configuration.nix here. Keeping it
  # host-local prevents generated disk, filesystem, GPU, and firmware details
  # from leaking into reusable modules.

  ###########################################################
  # LOCALE
  ###########################################################

  i18n.defaultLocale = "en_US.UTF-8";

  ###########################################################
  # HOST PACKAGES
  ###########################################################

  environment.systemPackages = (import ../packages/system { inherit pkgs; }) ++ [
    pkgs.btop
    pkgs.fastfetch
    pkgs.htop
    pkgs.iproute2
  ];

  ###########################################################
  # ZERO-TRUST NETWORKING
  ###########################################################

  ivali.tailscale = {
    enable = true;
    # Keep first install non-interactive and resilient. Add a SOPS-managed
    # authKeyFile later if you want unattended tailnet enrollment.
    authKeyFile = null;
  };

  ###########################################################
  # NIX / GITOPS
  ###########################################################

  nix.settings.warn-dirty = false;

  system.autoUpgrade = {
    enable = true;
    flake = "git+${gitlabUrl}#${hostName}";
    flags = [ "--refresh" "--print-build-logs" ];
    dates = "04:30";
    randomizedDelaySec = "45min";
    allowReboot = false;
  };

  ###########################################################
  # SOPS
  ###########################################################

  sops = {
    age = {
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
    };
    defaultSopsFile = ../secrets/tailscale.yaml;
  };
}

