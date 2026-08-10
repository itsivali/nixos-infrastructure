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
# boot.kernelModules, boot.kernelParams, hardware.enableAllFirmware
#
# RTL8821CE WiFi (Lenovo AMD laptop)
# ----------------------------------
# The chipset is served by the in-kernel rtw88 driver
# (rtw88_8821ce), exactly as on Garuda/Arch where it is stable. The
# out-of-tree rtl8821ce module does not build against 7.x kernels, so it
# must not be used; using it (or blacklisting rtw88) leaves no WiFi on
# the latest kernels. rtw88 needs the rtl8821c firmware, provided by
# hardware.enableAllFirmware.
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
    # Zen kernel: newest mainline base with zen patches — the same kernel
    # line used by Garuda, where this hardware has no WiFi issues. Do NOT
    # pin the out-of-tree rtl8821ce driver: it does not build on 7.x.
    kernelPackages = pkgs.linuxPackages_zen;

    initrd.kernelModules = [
      "amdgpu"
    ];

    kernelModules = [
      "kvm-amd"
      "tun"
      "vhost"
      "vhost_net"
      "vhost_vsock"
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

  # Ensure WiFi (rtw88/rtl8821c), Bluetooth, and other device firmware is
  # installed — rtw88 fails to probe without its firmware.
  hardware.enableAllFirmware = true;
}
