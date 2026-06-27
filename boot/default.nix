# boot/default.nix
#
# Bootloader, kernel, TPM, sysctl tuning and zram configuration.
#
# Optimized for:
#   • Lenovo IdeaPad S145 (AMD Ryzen)
#   • NixOS
#   • Tailscale
#   • Secure Boot
#   • TPM2
#   • Virtualization
#   • Software development
#   • GitOps
#   • Security hardening

{ pkgs, ... }:

{
  imports = import ../lib/auto-imports.nix ./.;

  boot = {

    ############################################################
    # Kernel
    ############################################################

    kernelPackages = pkgs.linuxPackages_latest;

    initrd.kernelModules = [
      "amdgpu"
      "tpm_crb"
      "tpm_tis"
    ];

    kernelModules = [
      "kvm-amd"
      "tun"
      "vhost"
      "vhost_net"
      "vhost_vsock"
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

      "slab_nomerge"

      "randomize_kstack_offset=on"

      "init_on_alloc=1"

      "init_on_free=1"

      "vsyscall=none"

      "pti=on"

      ##########################################################
      # Networking
      ##########################################################

      "ipv6.autoconf=1"

      ##########################################################
      # Misc
      ##########################################################

      "nowatchdog"
    ];

    ############################################################
    # Sysctl
    ############################################################

    kernel.sysctl = {

      ##########################################################
      # Kernel
      ##########################################################

      "kernel.nmi_watchdog" = 0;

      "kernel.sched_autogroup_enabled" = 1;

      "kernel.kptr_restrict" = 2;

      "kernel.dmesg_restrict" = 1;

      "kernel.unprivileged_bpf_disabled" = 1;

      "kernel.kexec_load_disabled" = 1;

      "kernel.yama.ptrace_scope" = 2;

      "kernel.perf_event_paranoid" = 3;

      "kernel.unprivileged_userns_clone" = 0;

      "kernel.sysrq" = 0;

      ##########################################################
      # Memory
      ##########################################################

      "vm.swappiness" = 180;

      "vm.watermark_boost_factor" = 0;

      "vm.watermark_scale_factor" = 125;

      "vm.page-cluster" = 0;

      "vm.vfs_cache_pressure" = 50;

      "vm.dirty_background_ratio" = 5;

      "vm.dirty_ratio" = 10;

      "vm.max_map_count" = 1048576;

      ##########################################################
      # Filesystem
      ##########################################################

      "fs.file-max" = 2097152;

      "fs.inotify.max_user_watches" = 1048576;

      "fs.protected_symlinks" = 1;

      "fs.protected_hardlinks" = 1;

      "fs.protected_fifos" = 2;

      "fs.protected_regular" = 2;

      ##########################################################
      # Network Performance
      ##########################################################

      "net.core.default_qdisc" = "fq";

      "net.core.somaxconn" = 8192;

      "net.core.bpf_jit_harden" = 2;

      "net.ipv4.tcp_congestion_control" = "bbr";

      "net.ipv4.tcp_fastopen" = 3;

      "net.ipv4.tcp_syncookies" = 1;

      "net.ipv4.tcp_max_syn_backlog" = 8192;

      "net.ipv4.ip_local_port_range" = "10240 65535";

      ##########################################################
      # Network Security
      ##########################################################

      "net.ipv4.conf.all.accept_redirects" = 0;

      "net.ipv4.conf.default.accept_redirects" = 0;

      "net.ipv6.conf.all.accept_redirects" = 0;

      "net.ipv6.conf.default.accept_redirects" = 0;

      "net.ipv4.conf.all.send_redirects" = 0;

      "net.ipv4.conf.default.send_redirects" = 0;

      "net.ipv4.conf.all.accept_source_route" = 0;

      "net.ipv4.conf.default.accept_source_route" = 0;

      "net.ipv6.conf.all.accept_source_route" = 0;

      "net.ipv6.conf.default.accept_source_route" = 0;

      "net.ipv4.conf.all.log_martians" = 1;

      "net.ipv4.icmp_echo_ignore_broadcasts" = 1;

      "net.ipv4.icmp_ignore_bogus_error_responses" = 1;

      "net.ipv4.conf.all.rp_filter" = 2;

      "net.ipv4.conf.default.rp_filter" = 2;
    };

    ############################################################
    # Bootloader
    ############################################################

    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };

      efi.canTouchEfiVariables = true;

      grub.enable = false;
    };

    ############################################################
    # Cleanup
    ############################################################

    tmp.cleanOnBoot = true;
  };

  ##############################################################
  # TPM 2.0
  ##############################################################

  security = {

    lockKernelModules = true;

    protectKernelImage = true;

    tpm2 = {
      enable = true;

      pkcs11.enable = true;

      tctiEnvironment.enable = true;
    };
  };

  ##############################################################
  # zRAM
  ##############################################################

  zramSwap = {
    enable = true;

    algorithm = "zstd";

    memoryPercent = 100;

    priority = 100;
  };
}
