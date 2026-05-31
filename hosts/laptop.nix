{ config, gitlabUrl, hostName, pkgs, ... }:

{
  ###########################################################
  # HOST IDENTITY
  ###########################################################

  networking.hostName = hostName;

  ###########################################################
  # HARDWARE BOUNDARY
  ###########################################################

  # Keep hardware-specific disk and device state at the host edge. Replace
  # these labels with the generated hardware-configuration.nix values after
  # installation if the laptop uses different labels or filesystems.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };

  swapDevices = [ ];

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
    authKeyFile = config.sops.secrets.tailscale_authkey.path;
  };

  sops.secrets.tailscale_authkey = {
    sopsFile = ../secrets/tailscale.yaml;
    owner = "root";
    mode = "0400";
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
