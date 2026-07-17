##############################################################################
#
# Kernel
#
# Purpose
# -------
# Linux kernel selection, modules, and parameters.
#
# Ownership
# ---------
# boot.kernelPackages, boot.blacklistedKernelModules,
# boot.extraModulePackages, boot.initrd.kernelModules,
# boot.kernelModules, boot.kernelParams
#
# Does NOT Own
# ------------
# - Sysctl tuning (boot/sysctl.nix)
# - Bootloader (boot/loader.nix)
# - zRAM (boot/zram.nix)
# - TPM (boot/tpm.nix)
#
##############################################################################

{ pkgs, config, ... }:

{
  boot = {
    # Pin to 6.18 — rtl8821ce out-of-tree driver does not build on 7.x.
    kernelPackages = pkgs.linuxPackages_6_18;

    # Blacklist the in-kernel rtw88_8821ce driver (broken for RTL8821CE chipsets)
    # and use the out-of-tree rtl8821ce driver instead.
    blacklistedKernelModules = [ "rtw88_8821ce" ];

    extraModulePackages = with config.boot.kernelPackages; [ rtl8821ce ];

    initrd.kernelModules = [
      "amdgpu"
    ];

    kernelModules = [
      "kvm-amd"
      "tun"
      "vhost"
      "vhost_net"
      "vhost_vsock"
      "8821ce"
      "overlay" #needed for docker
    ];

    kernelParams = [
      ##########################################################
      # AMD
      ##########################################################
      "amdgpu.dc=1"
      "amdgpu.audio=0"
      "acpi_backlight=native"
      "acpi_osi=Linux"
      "amd_iommu=on"
      "iommu=pt"

      ##########################################################
      # Performance
      ##########################################################
      "quiet"
      "splash"
      "threadirqs"
      "mitigations=auto"

      ##########################################################
      # Security
      ##########################################################
      "page_alloc.shuffle=1"
      "init_on_alloc=1"
      "slab_nomerge"
      "randomize_kstack_offset=on"
      "vsyscall=none"
      "pti=on"

      ##########################################################
      # Silent boot
      ##########################################################
      "consoleLogLevel=3"
      "rd.udev.log_level=3"
      "rd.systemd.show_status=auto"

      ##########################################################
      # Networking
      ##########################################################
      "ipv6.autoconf=1"

      ##########################################################
      # Misc
      ##########################################################
      "nowatchdog"
    ];
  };
}
