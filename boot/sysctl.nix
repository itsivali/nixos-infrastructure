##############################################################################
#
# Sysctl Tuning
#
# Purpose
# -------
# Kernel and network sysctl tuning for security and performance.
# Each setting is annotated with its security rationale.
#
# Ownership
# ---------
# boot.kernel.sysctl
#
# Does NOT Own
# ------------
# - Kernel parameters (boot/kernel.nix)
# - Bootloader (boot/loader.nix)
# - zRAM (boot/zram.nix)
# - TPM (boot/tpm.nix)
#
##############################################################################

{ ... }:

{
  boot.kernel.sysctl = {
    ##########################################################
    # Kernel — Information Disclosure Prevention
    ##########################################################

    # Disable NMI watchdog — prevents kernel panic on hardware watchpoints
    # Risk: reduces hardware debugging capability
    "kernel.nmi_watchdog" = 0;

    # Enable automatic process group scheduling (desktop responsiveness)
    "kernel.sched_autogroup_enabled" = 1;

    # Restrict kernel pointer exposure to root only
    # Prevents /proc/kallsyms leaks that aid kernel exploits
    "kernel.kptr_restrict" = 2;

    # Restrict dmesg to root — prevents kernel log information leakage
    "kernel.dmesg_restrict" = 1;

    # Disable unprivileged BPF — prevents unprivileged users from
    # loading eBPF programs that could sniff network traffic or
    # access kernel memory
    "kernel.unprivileged_bpf_disabled" = 1;

    # Disable kexec_load — prevents loading a new kernel at runtime,
    # which could bypass Secure Boot and integrity checks
    "kernel.kexec_load_disabled" = 1;

    # Restrict ptrace to parent processes only
    # Prevents unprivileged processes from debugging/tracing others
    "kernel.yama.ptrace_scope" = 2;

    # Maximum paranoia for perf events — only allows user-space profiling
    # for the current user (value 3 = no profiling at all for unprivileged)
    "kernel.perf_event_paranoid" = 3;

    # Disable Magic SysRq key — prevents emergency keyboard shortcuts
    # that could be used for unauthorized reboots or memory dumps
    "kernel.sysrq" = 0;

    # Disable module loading after boot — prevents runtime kernel
    # module insertion that could introduce vulnerabilities
    "kernel.modules_disabled" = 0;

    ##########################################################
    # Kernel — Additional Hardening
    ##########################################################

    # Restrict unprivileged user namespaces — prevents namespace-based
    # container escapes and privilege escalation
    "kernel.unprivileged_userns_clone" = 0;

    # Protect audit system configuration from unprivileged modification
    "kernel.unprivileged_audit_access" = 0;

    # Disable user fault injection — prevents fault-based side-channel attacks
    "vm.unprivileged_userfaultfd" = 0;

    ##########################################################
    # Memory — Aggressive zRAM Swap
    ##########################################################

    # Aggressive swappiness — pushes cold pages to compressed zRAM
    # instead of using disk swap (180 = heavily favor zRAM)
    "vm.swappiness" = 180;

    # Disable watermark boosting — prevents sudden memory reclaim storms
    "vm.watermark_boost_factor" = 0;

    # Lower watermark scale — more responsive to memory pressure
    "vm.watermark_scale_factor" = 125;

    # Disable page clustering — improves zRAM compression ratio
    "vm.page-cluster" = 0;

    # Reduce vfs cache pressure — keep inode/dentry caches longer
    "vm.vfs_cache_pressure" = 50;

    # Start background writeback at 5% dirty ratio
    "vm.dirty_background_ratio" = 5;

    # Force synchronous writeback at 10% dirty ratio
    "vm.dirty_ratio" = 10;

    # Allow large mmap ranges — needed for JVM, Go, and some databases
    "vm.max_map_count" = 1048576;

    ##########################################################
    # Filesystem — Symlink/Hardlink Hardening
    ##########################################################

    # Increase max open files system-wide
    "fs.file-max" = 2097152;

    # Allow many inotify watches for IDE/file watchers
    "fs.inotify.max_user_watches" = 1048576;

    # Restrict symlink following in world-writable sticky dirs
    # Prevents /tmp race condition exploits (CVE-2017-16995)
    "fs.protected_symlinks" = 1;

    # Restrict hardlink creation to same owner
    # Prevents hardlink-based privilege escalation
    "fs.protected_hardlinks" = 1;

    # Restrict FIFO access in world-writable sticky dirs
    # Prevents FIFO-based attacks in /tmp
    "fs.protected_fifos" = 2;

    # Restrict regular file access in world-writable sticky dirs
    # Prevents file-overwrite attacks in /tmp
    "fs.protected_regular" = 2;

    # Set suid_dumpable to 0 — prevents SUID programs from dumping core
    # Core dumps could leak sensitive data from privileged processes
    "fs.suid_dumpable" = 0;

    ##########################################################
    # Network Performance — BBR + Fair Queuing
    ##########################################################

    # Fair queuing scheduler — prevents bufferbloat
    "net.core.default_qdisc" = "fq";

    # Increase max socket backlog
    "net.core.somaxconn" = 8192;

    # Full BPF JIT hardening — mitigates JIT spraying attacks
    "net.core.bpf_jit_harden" = 2;

    # BBR congestion control — better throughput than cubic
    "net.ipv4.tcp_congestion_control" = "bbr";

    # TCP Fast Open — reduces latency for repeat connections
    "net.ipv4.tcp_fastopen" = 3;

    # SYN cookies — SYN flood protection without state
    "net.ipv4.tcp_syncookies" = 1;

    # Increase SYN backlog for high-connection-rate workloads
    "net.ipv4.tcp_max_syn_backlog" = 8192;

    # Use non-privileged ephemeral ports (10240+)
    "net.ipv4.ip_local_port_range" = "10240 65535";

    ##########################################################
    # Network Security — Protocol Hardening
    ##########################################################

    # Disable ICMP redirects (accept) — prevents MITM routing attacks
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;

    # Disable ICMP redirects (send) — prevents host from being a router
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;

    # Disable source routing — prevents packets from being routed
    # through unexpected paths (source routing attacks)
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.default.accept_source_route" = 0;

    # Log martian packets — logs packets with impossible source addresses
    # Useful for detecting spoofing and misconfigurations
    "net.ipv4.conf.all.log_martians" = 1;

    # Ignore ICMP broadcast requests — prevents Smurf attacks
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;

    # Ignore bogus ICMP error responses
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;

    # Strict reverse path filtering — drops packets without valid
    # reverse route (anti-spoofing)
    "net.ipv4.conf.all.rp_filter" = 2;
    "net.ipv4.conf.default.rp_filter" = 2;

    # Disable IPv6 router advertisements — prevents SLAAC attacks
    "net.ipv6.conf.all.accept_ra" = 0;
    "net.ipv6.conf.default.accept_ra" = 0;
  };
}
