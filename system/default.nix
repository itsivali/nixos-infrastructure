##############################################################################
#
# System Module
#
# Purpose
# -------
# Compose system-level configuration modules.
#
# Ownership
# ---------
# Imports only — no configuration.
#
# Responsibilities
# ----------------
# - nix.nix  — Nix daemon settings and garbage collection
# - users.nix — System user definitions
# - state.nix — System state version
#
##############################################################################

{ ... }:

{
  imports = import ../lib/auto-imports.nix ./.;
}
