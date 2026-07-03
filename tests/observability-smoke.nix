{ pkgs }:

pkgs.nixosTest {
  name = "observability-smoke";

  nodes.machine = { ... }: {
    imports = [
      ../boot
      ../networking
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
    };

    services.prometheus = {
      enable = true;
      port = 9090;
      scrapeConfigs = [];
    };

    services.grafana = {
      enable = true;
      settings.server.http_addr = "127.0.0.1";
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
