# boot/default.nix
#
# Kernel, bootloader, sysctl tuning, and zram configuration.
# Drop additional *.nix files here to extend boot behaviour:
#   e.g. secure-boot.nix, plymouth.nix, initrd-ssh.nix
{ pkgs, ... }:
{
  imports = import ../lib/auto-imports.nix ./.;

  boot = {
    # Mainline latest kernel — tracks upstream stable releases.
    # Prefer over zen for better hardware compatibility and timely
    # TPM2/fTPM driver fixes on AMD Ryzen/Zen+ platforms.
    kernelPackages = pkgs.linuxPackages_latest;

    initrd.kernelModules = [
      "amdgpu"   # early display handoff — avoids black screen under GDM
      "tpm_crb"  # AMD firmware TPM (fTPM) via CRB interface; must be in initrd
                 # for measured boot / Secure Boot / future LUKS-TPM unlock
      "tpm_tis"  # TIS-interface fallback; harmless if tpm_crb already claims device
    ];

    kernelModules = [
      "kvm-amd"  # AMD-V hardware virtualisation support
    ];

    kernelParams = [
      # ── AMD GPU ──────────────────────────────────────────────────────────────
      "amdgpu.dc=1"         # Display Core — required for Zen/Zen+ APUs
      "amdgpu.audio=0"      # disable HDMI audio via amdgpu; use snd_hda_intel

      # ── Lenovo IdeaPad S145 / AMD platform tweaks ────────────────────────────
      "acpi_backlight=native"   # native ACPI backlight; fixes Fn-key brightness control
      "acpi_osi=Linux"          # advertise Linux to firmware for correct power paths
      "amd_iommu=on"            # enable AMD-Vi IOMMU (device isolation + virt support)
      "iommu=pt"                # pass-through mode — avoids unnecessary DMA-remapping overhead

      # ── Scheduler / latency ──────────────────────────────────────────────────
      "quiet"
      "splash"
      "threadirqs"              # per-thread IRQ handling for lower scheduling latency
      "nowatchdog"
      "mitigations=auto"        # apply CPU mitigations only where the hardware needs them
    ];

    kernel.sysctl = {
      # ── Watchdog ─────────────────────────────────────────────────────────────
      "kernel.nmi_watchdog"            = 0;

      # ── Scheduler ────────────────────────────────────────────────────────────
      "kernel.sched_autogroup_enabled" = 1;

      # ── VM / zram (tuned for 100 % zram swap) ────────────────────────────────
      "vm.swappiness"             = 180;
      "vm.watermark_boost_factor" = 0;
      "vm.watermark_scale_factor" = 125;
      "vm.page-cluster"           = 0;
      "vm.vfs_cache_pressure"     = 50;
      "vm.dirty_background_ratio" = 5;
      "vm.dirty_ratio"            = 10;

      # ── Filesystem ───────────────────────────────────────────────────────────
      "fs.inotify.max_user_watches" = 1048576;

      # ── Network ──────────────────────────────────────────────────────────────
      "net.core.default_qdisc"          = "fq";
      "net.ipv4.tcp_congestion_control" = "bbr";
      "net.ipv4.tcp_fastopen"           = 3;    # TFO for both client and server

      # ── Security / hardening ─────────────────────────────────────────────────
      "kernel.kptr_restrict" = 1;  # hide kernel pointers from unprivileged /proc reads
      "kernel.dmesg_restrict" = 1; # restrict dmesg output to root / CAP_SYSLOG
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

  # ── TPM 2.0 ──────────────────────────────────────────────────────────────────
  # On the IdeaPad S145-15AST the TPM is provided by the AMD PSP (firmware TPM).
  # This exposes /dev/tpm0 (raw char device) and /dev/tpmrm0 (kernel resource mgr).
  #
  # ⚠  BIOS prerequisite: enable "Security Device Support" / "fTPM" in UEFI setup
  #    before rebuilding — the device node will not appear otherwise.
  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;          # expose TPM2 as a PKCS#11 token (SSH keys, certs)
    tctiEnvironment.enable = true; # set TPM2TOOLS_TCTI so tpm2-tools CLI works without flags
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
    priority = 100;
  };
}