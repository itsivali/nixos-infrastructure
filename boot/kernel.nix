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

    # Blacklist broken kernel modules at boot to prevent device-probe
    # timeouts. The Lenovo BIOS exposes a TPM2 ACPI table (MSFT0101)
    # but the tpm_crb driver fails with EBUSY, causing systemd to wait
    # 90s × 2 for /dev/tpm0 and /dev/tpmrm0 (~3 min lost). The
    # 8250 serial ports don't exist on this laptop but each times out
    # at 90s (4 ports × 90s = ~6 min). Together these add ~9 min to
    # every boot.
    blacklistedKernelModules = [
      "tpm_crb"
      "tpm_tis"
      "tpm_tis_infineon"
      "tpm_tis_core"
      "tpm.Atmel"
      "tpm.Infineon"
      "tpm.NSCS"
      "tpm.ST33"
      "tpm.Xilinx"
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
      # Hardware: disable serial ports (no physical UART on this laptop)
      ##########################################################
      "8250.nr_uarts=0"
      "8250_acpi.nr_uarts=0"

      ##########################################################
      # USB: disable autosuspend globally.
      # On this Lenovo AMD laptop, the EHCI/xHCI controllers enter
      # suspended state and fail to wake on new device plug-in.
      # usbcore.autosuspend=-1 prevents the kernel from ever
      # auto-suspending USB controllers or devices.
      ##########################################################
      "usbcore.autosuspend=-1"

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
