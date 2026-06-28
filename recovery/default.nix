##############################################################################
#
# Recovery Module
#
# Purpose
# -------
# Compose recovery and self-healing modules.
#
# Ownership
# ---------
# Imports only — no configuration.
#
# Responsibilities
# ----------------
# - deployment-health.nix — Health-check service + 5-minute timer
# - rollback.nix          — Self-heal service that triggers on failure
#
##############################################################################

{ ... }:

{
  imports = import ../lib/auto-imports.nix ./.;
}
