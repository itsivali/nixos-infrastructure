# recovery/default.nix
#
# Domain entry-point for recovery and self-healing modules.
# Automatically imports every *.nix file placed in this directory.
#
# Current auto-discovered modules:
#   deployment-health.nix  ← health-check service + 5-minute timer
#   rollback.nix           ← self-heal service that triggers on failure
#
# To add a new recovery module (e.g. snapshot.nix), just drop it here.
{ ... }:
{
  imports = import ../lib/auto-imports.nix ./.;
}
