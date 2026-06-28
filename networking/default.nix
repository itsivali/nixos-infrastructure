##############################################################################
#
# Networking Module
#
# Purpose
# -------
# Compose networking-related configuration modules.
#
# Ownership
# ---------
# Imports only — no configuration.
#
# Responsibilities
# ----------------
# - time.nix          — Time zone
# - networkmanager.nix — NetworkManager, systemd-resolved, DNS
#
##############################################################################

{ ... }:

{
  imports = import ../lib/auto-imports.nix ./.;
}
