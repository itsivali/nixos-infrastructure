##############################################################################
#
# Services Smoke
#
# Purpose
# -------
# Test service stubs (nginx, postgres, valkey).
#
##############################################################################

{ pkgs, sops-nix, home-manager }:

pkgs.testers.nixosTest {
  name = "services-smoke";

  nodes.machine = { ... }: {
    imports = [
      ../services/nginx
      ../services/postgres
      ../services/redis
    ];

    networking.hostName = "services-smoke";
    services.xserver.enable = false;
    services.openssh.enable = false;

    ivali.services.nginx.enable = true;
    ivali.services.postgres.enable = true;
    ivali.services.valkey.enable = true;

    system.stateVersion = "26.11";
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Test nginx
    machine.succeed("systemctl is-active nginx.service")
    machine.succeed("curl -s http://localhost:80/ | head -1")

    # Test postgres
    machine.succeed("systemctl is-active postgresql.service")
    machine.succeed("sudo -u postgres psql -c 'SELECT 1;'")

    # Test valkey
    machine.succeed("systemctl is-active valkey.service")
    machine.succeed("valkey-cli ping | grep PONG")
  '';
}
