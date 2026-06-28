##############################################################################
#
# Core Shell
#
# Purpose
# -------
# Compose core shell environment modules.
#
# Ownership
# ---------
# Imports only — no configuration.
#
# Responsibilities
# ----------------
# - bash.nix
# - zsh.nix
# - history.nix
# - completion.nix
# - keybindings.nix
# - prompt.nix
# - startup/
#
##############################################################################

{ ... }:

{
  imports = [
    ./bash.nix
    ./zsh.nix
    ./history.nix
    ./completion.nix
    ./keybindings.nix
    ./prompt.nix
    ./startup
  ];
}
