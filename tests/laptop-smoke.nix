{ pkgs }:

pkgs.nixosTest {
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
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.succeed("systemctl is-active systemd-resolved.service")
    machine.succeed("sysctl vm.swappiness | grep 180")
  '';
}
