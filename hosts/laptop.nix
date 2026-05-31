{ gitlabUrl, hostName, pkgs, ... }:

{
  networking.hostName = hostName;

  # Replace these placeholder labels with the real laptop disk labels after
  # installation or hardware scan.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };

  swapDevices = [ ];

  environment.systemPackages = import ../packages/system { inherit pkgs; };

  ivali.tailscale.enable = true;

  system.autoUpgrade = {
    enable = true;
    flake = "git+${gitlabUrl}#${hostName}";
    flags = [ "--refresh" "--print-build-logs" ];
    dates = "04:30";
    randomizedDelaySec = "45min";
    allowReboot = false;
  };

  sops = {
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    defaultSopsFile = ../secrets/example.yaml;
  };
}
