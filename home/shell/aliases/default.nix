##############################################################################
#
# Shell Aliases
#
# Purpose
# -------
# Compose alias modules by domain.
#
# Ownership
# ---------
# Imports only — no configuration.
#
# Responsibilities
# ----------------
# - navigation.nix
# - git.nix
# - nix.nix
# - development.nix
# - utilities.nix
#
##############################################################################

{ ... }:

{
  imports = [
    ./navigation.nix
    ./git.nix
    ./nix.nix
    ./development.nix
    ./utilities.nix
  ];
}
