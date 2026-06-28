##############################################################################
#
# Cloud Module
#
# Purpose
# -------
# Compose cloud provider configuration modules.
#
# Ownership
# ---------
# Imports only — no configuration.
#
# Responsibilities
# ----------------
# - hetzner/     — Hetzner Cloud (future)
# - digitalocean/ — DigitalOcean (future)
# - aws/         — Amazon Web Services (future)
#
##############################################################################

{ ... }:

{
  imports = import ../lib/auto-imports.nix ./.;
}
