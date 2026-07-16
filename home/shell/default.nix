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
# - aliases/      — Domain-grouped shell aliases
# - bitwarden/    — Bitwarden CLI integration (auth, clipboard, cache, search)
# - core/         — Bash, Zsh, history, completion, keybindings, prompt, startup
# - integrations/ — Direnv, FZF, Zoxide, Atuin
# - tools/        — Bat, Btop, Eza, Fastfetch, shell packages
#
##############################################################################

{ ... }:

{
  imports = import ../../lib/auto-imports.nix ./.;
}
