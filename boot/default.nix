# boot/default.nix
#
# Kernel, bootloader, sysctl tuning, and zram configuration.
# Drop additional *.nix files here to extend boot behaviour:
#   e.g. secure-boot.nix, plymouth.nix, initrd-ssh.nix
{ pkgs, ... }:
{
  imports = import ../lib/auto-imports.nix ./.;

  boot = {
    kernelPackages = pkgs.linuxPackages_zen;

    # Load amdgpu in initrd so the display is handed off cleanly
    # from the kernel to the display manager. Without this the screen
    # goes black with a cursor when GDM takes over.
    initrd.kernelModules = [ "amdgpu" ];

    kernelParams = [
      "amdgpu.dc=1" # enable Display Core — required for modern AMD APUs/GPUs
      "amdgpu.audio=0" # disable HDMI audio via amdgpu (use snd_hda_intel instead)
      "quiet"
      "splash"
      "threadirqs"
      "nowatchdog"
      "mitigations=auto"
    ];

    kernel.sysctl = {
      "kernel.nmi_watchdog" = 0;
      "kernel.sched_autogroup_enabled" = 1;
      "vm.swappiness" = 180;
      "vm.watermark_boost_factor" = 0;
      "vm.watermark_scale_factor" = 125;
      "vm.page-cluster" = 0;
      "vm.vfs_cache_pressure" = 50;
      "vm.dirty_background_ratio" = 5;
      "vm.dirty_ratio" = 10;
      "fs.inotify.max_user_watches" = 1048576;
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_congestion_control" = "bbr";
    };

    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };
      efi.canTouchEfiVariables = true;
      grub.enable = false;
    };

    tmp.cleanOnBoot = true;
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
    priority = 100;
  };
}
