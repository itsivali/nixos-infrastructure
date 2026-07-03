##############################################################################
#
# Automation Smoke
#
# Purpose
# -------
# Test automation services (GitOps reconciler, health checks).
#
##############################################################################

{ pkgs }:

pkgs.testers.nixosTest {
  name = "automation-smoke";

  nodes.machine = { ... }: {
    imports = [
      ../automation
    ];

    networking.hostName = "automation-smoke";
    services.xserver.enable = false;
    services.openssh.enable = false;

    ivali.automation.gitops.enable = true;
    ivali.recovery.health.enable = true;

    system.stateVersion = "26.11";
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Test health check service
    machine.succeed("systemctl is-active deployment-health.service")

    # Test health check timer
    machine.succeed("systemctl is-active deployment-health.timer")

    # Test gitops timer
    machine.succeed("systemctl is-active gitops-reconcile.timer")
  '';
}
