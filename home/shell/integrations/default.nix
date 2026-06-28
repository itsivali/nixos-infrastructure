##############################################################################
#
# Shell Integrations
#
# Purpose
# -------
# Compose third-party shell integration modules.
#
# Ownership
# ---------
# Imports only — no configuration.
#
# Responsibilities
# ----------------
# - direnv.nix
# - fzf.nix
# - zoxide.nix
# - atuin.nix
#
##############################################################################

{ ... }:

{
  imports = [
    ./direnv.nix
    ./fzf.nix
    ./zoxide.nix
    ./atuin.nix
  ];
}
