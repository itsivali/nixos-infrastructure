##############################################################################
#
# Services Module
#
# Purpose
# -------
# Compose service-related configuration modules.
#
# Ownership
# ---------
# Imports only — no configuration.
#
# Responsibilities
# ----------------
# - msmtp/    — Outbound SMTP relay for notifications
# - nginx/    — Web server (future)
# - postgres/ — Database (future)
# - redis/    — Cache (future)
#
##############################################################################

{ ... }:

{
  imports = import ../lib/auto-imports.nix ./.;
}
