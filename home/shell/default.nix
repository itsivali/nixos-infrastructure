##############################################################################
#
# Home Manager Shell Configuration Module Root
#
# Purpose
# -------
# Aggregates and loads all shell subsystem modules.
#
# Ownership
# ---------
# Imports only — no configuration.
#
# Responsibilities
# ----------------
# - core/        — Bash, Zsh, history, completion, keybindings, prompt, startup
# - integrations/ — Direnv, FZF, Zoxide, Atuin
# - tools/       — Bat, Btop, Eza, Fastfetch, shell packages
# - aliases/     — Domain-grouped shell aliases
# - bitwarden.nix — Bitwarden CLI integration
#
##############################################################################

{ ... }:

{
  imports = [
    ./core
    ./integrations
    ./tools
    ./aliases
    ./bitwarden.nix
  ];
}
