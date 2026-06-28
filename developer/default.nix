##############################################################################
#
# Developer Module
#
# Purpose
# -------
# Compose developer tooling modules.
#
# Ownership
# ---------
# Imports only — no configuration.
#
# Responsibilities
# ----------------
# - shell.nix     — Default login shell
# - docker.nix    — Docker container runtime
# - languages.nix — Language runtimes and tooling
#
##############################################################################

{ ... }:

{
  imports = import ../lib/auto-imports.nix ./.;
}
