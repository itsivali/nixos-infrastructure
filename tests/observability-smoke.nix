##############################################################################
#
# Tests Observability Smoke
#
# Purpose
# -------
# NixOS VM smoke test that validates the observability stack including
# Prometheus, Grafana, the health endpoint, and the NixOS exporter.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Verify Prometheus service is running
# - Verify Grafana service is running
# - Verify health endpoint responds on port 9100
# - Verify NixOS exporter port 9101 is open
#
##############################################################################

{ pkgs, sops-nix, home-manager }:

pkgs.testers.nixosTest {
  name = "observability-smoke";

  nodes.machine = { ... }: {
    imports = [
      sops-nix.nixosModules.sops
      ../boot
      ../networking
      ../security/sops.nix
      ../observability
    ];

    networking.hostName = "observability-smoke";
    services.xserver.enable = false;
    services.openssh.enable = false;
    system.stateVersion = "26.11";

    ivali.observability = {
      enable = true;
      alloy.enable = false;
      falco.enable = false;
      exporters.enable = true;
      healthEndpoint.enable = true;
      # No SOPS key material in this test VM — Grafana is started with a
      # throwaway secret key set directly on services.grafana (see below).
      grafana.allowDefaultCredentials = true;
    };

    # No SOPS key material in this test VM.  The nixpkgs grafana module
    # (26.05+) requires settings.security.secret_key to be set, so provide
    # a throwaway test-only value directly.  Production hosts always have
    # ivali.secrets.enable = true and receive the real key via SOPS.
    ivali.secrets.enable = false;

    services.prometheus = {
      enable = true;
      port = 9090;
      scrapeConfigs = [ ];
    };

    services.grafana = {
      enable = true;
      settings.server.http_addr = "127.0.0.1";
      settings.security.secret_key = "test-only-not-a-real-secret";
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Prometheus running
    machine.wait_for_unit("prometheus.service")
    machine.succeed("systemctl is-active prometheus.service")

    # Grafana running
    machine.wait_for_unit("grafana.service")
    machine.succeed("systemctl is-active grafana.service")

    # Health endpoint responding
    machine.wait_for_unit("health-endpoint.service")
    machine.succeed("curl -s http://127.0.0.1:9100/ | grep -q status")

    # Exporter port open
    machine.succeed("ss -tlnp | grep 9101")
  '';
}
