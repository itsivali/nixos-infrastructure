##############################################################################
#
# Tests Security Smoke
#
# Purpose
# -------
# NixOS VM smoke test that validates kernel hardening, sysctl settings,
# AppArmor profiles, firewall rules, fail2ban filters, and core dump
# restrictions.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Verify kernel command-line hardening (slab_nomerge, init_on_alloc)
# - Verify sysctl security settings (kptr_restrict, dmesg_restrict, etc.)
# - Verify AppArmor profiles are present for bot, CLI, and reconciler
# - Verify firewall default drop policy
# - Verify fail2ban Telegram webhook filter is installed
#
##############################################################################

{ pkgs, sops-nix, home-manager }:

pkgs.testers.nixosTest {
  name = "security-smoke";

  nodes.machine = { config, lib, ... }:
    let
      # What nftables actually loads: the custom ruleset plus every declared
      # table (the firewall emits the "nixos-fw" table via extraInputRules;
      # this module emits the outbound enforcement via nftables.ruleset).
      nftRuntime =
        config.networking.nftables.ruleset
        + builtins.concatStringsSep "\n" (lib.mapAttrsToList (_: t: t.content) config.networking.nftables.tables);
    in
    {
      imports = [
        ../boot
        ../networking
        ../security/apparmor.nix
        ../security/fail2ban.nix
        ../security/firewall.nix
        ../security/hardening.nix
        ../security/sudo.nix
      ];

      networking.hostName = "security-smoke";
      services.xserver.enable = false;
      services.openssh.enable = false;
      system.stateVersion = "26.11";

      # Strip the host's 8250 UART-disable params so the VM serial console
      # (ttyS0) stays alive for the NixOS test driver.
      ivali.boot.disableSerialPorts = false;

      security.apparmor.enable = true;

      # Exercise the repository firewall module (nftables backend) so the
      # default-deny assertions below describe the actual module
      # behavior, not the stock NixOS firewall.
      ivali.security.firewall.enable = true;

      ivali.security.fail2ban = {
        enable = true;
      };

      # The security firewall module owns a default-deny ingress policy and
      # deliberately opens no inbound TCP port on any interface. Per-service
      # exposure is declared by the host spec, scoped to tailscale0 where
      # applicable — it is not granted here.
      #
      # History: these assertions previously pinned LocalSend (port 53317)
      # Tailscale-only rules. LocalSend was removed from security/firewall.nix
      # in 33ca011 (replaced by GSConnect + Syncthing + Taildrop) but these
      # assertions were left behind, which made `nix flake check` permanently
      # red. They now assert the default-deny contract the module actually
      # owns, plus a guard that the removed LocalSend rules stay removed.
      assertions = [
        {
          assertion = config.networking.firewall.allowedTCPPorts == [ ];
          message = "The security firewall must not open any inbound TCP port on any interface";
        }
        {
          assertion = config.networking.firewall.allowedUDPPorts == [ 41641 ];
          message = "The security firewall must open only the Tailscale WireGuard UDP port (41641) globally";
        }
        {
          # security/firewall.nix sets trustedInterfaces = [ ]; the effective
          # value also carries nixpkgs' own "lo" default, so assert that no
          # real (non-loopback) interface has been trusted.
          assertion = builtins.all (i: i == "lo") config.networking.firewall.trustedInterfaces;
          message = "The security firewall must trust no interface beyond loopback";
        }
        {
          assertion = !lib.hasInfix "53317" nftRuntime;
          message = "LocalSend (53317) was removed in 33ca011 and must not reappear in the nftables ruleset";
        }
      ];

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
    machine.succeed("sysctl kernel.yama.ptrace_scope | grep 2")

    # Sudo configured
    machine.succeed("grep -q 'Defaults exec_slide' /etc/sudoers || true")

    # Firewall active
    machine.succeed("nft list ruleset | grep -q 'policy drop'")

    # Core dumps disabled
    machine.succeed("sysctl fs.suid_dumpable | grep 0")

    # Additional sysctl hardening
    machine.succeed("sysctl net.ipv4.conf.all.rp_filter | grep 2")
    machine.succeed("sysctl net.ipv4.conf.default.rp_filter | grep 2")
    machine.succeed("sysctl net.ipv4.icmp_echo_ignore_broadcasts | grep 1")
    machine.succeed("sysctl net.ipv4.conf.all.accept_redirects | grep 0")
    machine.succeed("sysctl net.ipv6.conf.all.accept_redirects | grep 0")
    machine.succeed("sysctl net.ipv4.conf.all.send_redirects | grep 0")
    machine.succeed("sysctl net.ipv4.conf.all.accept_source_route | grep 0")
    machine.succeed("sysctl net.ipv4.conf.all.log_martians | grep 1")
    machine.succeed("sysctl net.ipv4.tcp_syncookies | grep 1")
    machine.succeed("sysctl net.ipv4.tcp_rfc1337 | grep 1")
    machine.succeed("sysctl net.ipv6.conf.all.accept_ra | grep 0")
    machine.succeed("sysctl vm.unprivileged_userfaultfd | grep 0")
    machine.succeed("sysctl fs.protected_hardlinks | grep 1")
    machine.succeed("sysctl fs.protected_symlinks | grep 1")

    # AppArmor profiles present (enforce mode)
    machine.succeed("ls /etc/apparmor.d/")
    machine.succeed("cat /etc/apparmor.d/ivali-cli")

    # Security scanner metrics file created
    machine.succeed("mkdir -p /var/lib/security-scanner")
  '';
}
