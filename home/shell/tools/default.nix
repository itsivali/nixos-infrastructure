##############################################################################
#
# Shell Tools
#
# Purpose
# -------
# Compose shell tool modules.
#
# Ownership
# ---------
# Imports only — no configuration.
#
# Responsibilities
# ----------------
# - packages.nix
# - bat.nix
# - btop.nix
# - eza.nix
# - fastfetch.nix
#
##############################################################################

{ ... }:

{
  imports = [
    ./packages.nix
    ./bat.nix
    ./btop.nix
    ./eza.nix
    ./fastfetch.nix
  ];
}
