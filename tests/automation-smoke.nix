##############################################################################
#
# Automation Smoke
#
# Purpose
# -------
# Test automation services (GitOps reconciler, health checks).
#
##############################################################################

{ pkgs, sops-nix, home-manager }:

pkgs.testers.nixosTest {
  name = "automation-smoke";

  nodes.machine = { ... }: {
    imports = [
      sops-nix.nixosModules.sops
      ../security/sops.nix
      ../automation
      ../recovery
    ];

    networking.hostName = "automation-smoke";
    services.xserver.enable = false;
    services.openssh.enable = false;

    fleet.gitops.repo = "https://gitlab.com/willisivali/nixos-infrastructure";
    fleet.gitops.branch = "main";
    fleet.deploymentHealth.enable = true;
    fleet.gitopsReconciler.enable = true;

    system.stateVersion = "26.11";
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Health check is a oneshot driven by its timer; verify the timer is active.
    machine.succeed("systemctl is-active deployment-health.timer")

    # GitOps reconciler timer (enabled on prague) is active.
    machine.succeed("systemctl is-active gitops-reconciler.timer")
  '';
}
