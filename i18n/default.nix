##############################################################################
#
# i18n Module
#
# Purpose
# -------
# Compose internationalisation and locale configuration modules.
#
# Ownership
# ---------
# Imports only — no configuration.
#
# Responsibilities
# ----------------
# - locale.nix  — Default system locale
#
##############################################################################

{ ... }:

{
  imports = import ../lib/auto-imports.nix ./.;
}
