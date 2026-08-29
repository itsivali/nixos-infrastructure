##############################################################################
#
# Environment Module
#
# Purpose
# -------
# Compose Home Manager environment modules.
#
# Ownership
# ---------
# Imports only — no configuration.
#
# Responsibilities
# ----------------
# - locale.nix     — Locale settings
# - mime.nix       — MIME type default applications
# - packages.nix   — User environment packages
# - session.nix    — Session settings
# - variables.nix  — Environment variables
# - xdg.nix        — XDG base directory settings
# - ai-cleanup.nix — Remove legacy imperative AI tool binaries
#
##############################################################################

{ ... }:

{
  imports = [
    ./locale.nix
    ./mime.nix
    ./packages.nix
    ./session.nix
    ./variables.nix
    ./xdg.nix
    ./ai-cleanup.nix
  ];
}
