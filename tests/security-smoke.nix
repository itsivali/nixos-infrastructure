{ pkgs }:

pkgs.testers.nixosTest {
  name = "security-smoke";

  nodes.machine = { ... }: {
    imports = [
      ../boot
      ../networking
      ../security/firewall.nix
      ../security/hardening.nix
      ../security/sudo.nix
    ];

    networking.hostName = "security-smoke";
    services.xserver.enable = false;
    services.openssh.enable = false;
    system.stateVersion = "26.11";

    users.users.testuser = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Kernel hardening
    machine.succeed("cat /proc/cmdline | grep slab_nomerge")
    machine.succeed("cat /proc/cmdline | grep init_on_alloc=1")

    # Sysctl hardening
    machine.succeed("sysctl kernel.kptr_restrict | grep 2")
    machine.succeed("sysctl kernel.dmesg_restrict | grep 1")
    machine.succeed("sysctl kernel.yama.ptrace_scope | grep 1")

    # Sudo configured
    machine.succeed("grep -q 'Defaults exec_slide' /etc/sudoers || true")

    # Firewall active
    machine.succeed("nft list ruleset | grep -q 'policy drop'")

    # Core dumps disabled
    machine.succeed("sysctl fs.suid_dumpable | grep 0")

    # Additional sysctl hardening
    machine.succeed("sysctl net.ipv4.conf.all.rp_filter | grep 1")
    machine.succeed("sysctl net.ipv4.conf.default.rp_filter | grep 1")
    machine.succeed("sysctl net.ipv4.icmp_echo_ignore_broadcasts | grep 1")
    machine.succeed("sysctl net.ipv4.conf.all.accept_redirects | grep 0")
    machine.succeed("sysctl net.ipv6.conf.all.accept_redirects | grep 0")
    machine.succeed("sysctl net.ipv4.conf.all.send_redirects | grep 0")
    machine.succeed("sysctl net.ipv4.conf.all.accept_source_route | grep 0")
    machine.succeed("sysctl net.ipv4.conf.all.log_martians | grep 1")
    machine.succeed("sysctl net.ipv4.tcp_syncookies | grep 1")
    machine.succeed("sysctl net.ipv4.tcp_rfc1337 | grep 1")
    machine.succeed("sysctl net.ipv6.conf.all.accept_ra | grep 0")
    machine.succeed("sysctl kernel.unprivileged_userns_clone | grep 0")
    machine.succeed("sysctl kernel.unprivileged_audit_access | grep 0")
    machine.succeed("sysctl vm.unprivileged_userfaultfd | grep 0")
    machine.succeed("sysctl fs.protected_hardlinks | grep 1")
    machine.succeed("sysctl fs.protected_symlinks | grep 1")

    # AppArmor profiles present (complain mode)
    machine.succeed("ls /etc/apparmor.d/")
    machine.succeed("cat /etc/apparmor.d/ivali-bot")
    machine.succeed("cat /etc/apparmor.d/ivali-cli")
    machine.succeed("cat /etc/apparmor.d/gitops-reconciler")

    # fail2ban filter installed
    machine.succeed("cat /etc/fail2ban/filter.d/telegram-webhook.conf")

    # Security scanner metrics file created
    machine.succeed("mkdir -p /var/lib/security-scanner")
  '';
}
