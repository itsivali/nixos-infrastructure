# ci/default.nix
#
# Domain entry-point for CI/CD modules.
# Automatically imports every *.nix file placed in this directory.
#
# Current auto-discovered modules:
#   gitlab-runner.nix  ← self-healing GitLab Runner fleet
#
# To add a new CI module (e.g. cache-server.nix), just drop it here.
{ ... }:
{
  imports = import ../lib/auto-imports.nix ./.;
}
