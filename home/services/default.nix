##############################################################################
#
# Services Module
#
# Purpose
# -------
# Compose Home Manager user service modules.
#
# Ownership
# ---------
# Imports only — no configuration.
#
# Responsibilities
# ----------------
# - auto-format.nix — Nix file auto-formatter as a systemd user service
#
##############################################################################

{ ... }:

{
  imports = [
    ./auto-format.nix
  ];
}
