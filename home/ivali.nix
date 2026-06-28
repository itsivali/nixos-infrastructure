##############################################################################
#
# Home Manager Identity — ivali
#
# Purpose
# -------
# User-specific identity configuration.
#
# Ownership
# ---------
# Imports only — delegates to home/identity/
#
# This file exists as the user-specific entry point.
# All functional configuration lives in dedicated modules:
#   - identity/  — Home identity
#   - shell/     — Shell environments, tools, integrations, aliases
#   - git/       — Git configuration
#   - editors/   — Editor configuration (Zed)
#   - environment/ — Environment variables, locale, XDG
#   - services/  — User services (auto-format, etc.)
#   - fonts.nix  — Font configuration
#
##############################################################################

{ ... }:

{
  imports = [
    ./identity
  ];
}
