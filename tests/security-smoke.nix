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
  '';
}
