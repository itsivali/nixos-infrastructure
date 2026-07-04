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
# - packages.nix   — User environment packages
# - session.nix    — Session settings
# - variables.nix  — Environment variables
# - xdg.nix        — XDG base directory settings
# - extensions.nix — GNOME Shell extensions (dconf enablement)
#
##############################################################################

{ ... }:

{
  imports = [
    ./locale.nix
    ./packages.nix
    ./session.nix
    ./variables.nix
    ./xdg.nix
    ./extensions.nix
  ];
}
