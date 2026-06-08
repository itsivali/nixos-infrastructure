{ ... }:

{
  imports = [
    ./hosts/hardware-configuration.nix
    ./hosts/laptop.nix
    ./automation/gitops-reconciler.nix
    ./recovery/deployment-health.nix
    ./recovery/rollback.nix
    ./boot
    ./networking
    ./networking/msmtp
    ./security
    ./developer
    ./desktop/gnome-lean.nix
    ./observability
    ./ci/gitlab-runner.nix
  ];
}
