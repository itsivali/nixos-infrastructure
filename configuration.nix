{ ... }:

{
  imports = [
    ./hosts/laptop.nix
    ./boot
    ./networking
    ./security
    ./developer
    ./apps
    ./desktop/gnome-lean.nix
    ./observability
    ./ci/gitlab-runner.nix
  ];
}
