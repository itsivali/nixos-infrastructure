# automation/default.nix
#
# Domain entry-point for automation modules.
# Automatically imports every *.nix file placed in this directory
# and any sub-directory that contains a default.nix.
#
# Current auto-discovered modules:
#   gitops-reconciler.nix  ← GitOps reconciliation loop + timer
#
# To add a new automation module, just drop a .nix file here.
# Prefix helper / data files with _ to keep them out of auto-import:
#   _common.nix  (shared constants used by multiple scripts)
{ ... }:
{
  imports = import ../lib/auto-imports.nix ./.;
}
