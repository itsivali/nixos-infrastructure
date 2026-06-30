##############################################################################
#
# CI / CD Module
#
# Purpose
# -------
# Compose CI/CD runner and automation modules.
#
# Ownership
# ---------
# Imports only — no configuration.
#
# Responsibilities
# ----------------
# - gitlab-runner.nix — Self-healing GitLab Runner fleet
#
##############################################################################

{ ... }:

{
  imports =
    (import ../lib/auto-imports.nix ./.)
    ++ [
      ./ci-deploy.nix
    ];
}
