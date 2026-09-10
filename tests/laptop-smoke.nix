##############################################################################
#
# Laptop Smoke
#
# Purpose
# -------
# Auto-generated module description.
#
##############################################################################

{ pkgs, sops-nix, home-manager }:

pkgs.testers.nixosTest {
  name = "laptop-smoke";

  nodes.machine = { ... }: {
    imports = [
      ../boot
      ../networking
      ../security/firewall.nix
      ../security/tailscale.nix
    ];

    networking.hostName = "laptop-smoke";
    services.xserver.enable = false;
    services.openssh.enable = false;
    system.stateVersion = "26.11";

    # Strip the host's 8250 UART-disable params so the VM serial console
    # (ttyS0) stays alive for the NixOS test driver.
    ivali.boot.disableSerialPorts = false;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.succeed("systemctl is-active systemd-resolved.service")
    machine.succeed("sysctl vm.swappiness | grep 180")
  '';
}
