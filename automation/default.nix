##############################################################################
#
# Automation Module
#
# Purpose
# -------
# Compose fleet automation modules.
#
# Ownership
# ---------
# Imports only — no configuration.
#
# Responsibilities
# ----------------
# - options.nix          — Fleet options (gitops, notifications)
# - gitops-reconciler.nix — GitOps reconciliation loop + timer
# - _common.nix          — Shared constants (excluded from auto-import)
#
##############################################################################

{ ... }:

{
  imports = import ../lib/auto-imports.nix ./.;
}
