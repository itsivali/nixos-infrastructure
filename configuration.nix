{ ... }:

{
  imports = [
    ./hosts/laptop.nix
    ./boot
    ./networking
    ./security
    ./developer
    ./desktop/gnome-lean.nix
    ./observability
    ./ci/gitlab-runner.nix
  ];
}
