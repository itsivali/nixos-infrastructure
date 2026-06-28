##############################################################################
#
# Storage Module
#
# Purpose
# -------
# Compose storage-related configuration modules.
#
# Ownership
# ---------
# Imports only — no configuration.
#
# Responsibilities
# ----------------
# - btrfs.nix     — BTRFS filesystem tuning
# - tmpfs.nix     — tmpfs mounts (future)
# - encryption.nix — Disk encryption (future)
#
##############################################################################

{ ... }:

{
  imports = import ../lib/auto-imports.nix ./.;
}
