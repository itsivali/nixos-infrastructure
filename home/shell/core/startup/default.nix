##############################################################################
#
# Zsh Startup Sequence
#
# Purpose
# -------
# Compose the Zsh startup sequence in order.
#
# Ownership
# ---------
# Imports only — no configuration.
#
# Responsibilities
# ----------------
# - 10-instant-prompt  — Powerlevel10k instant prompt
# - 20-completion      — compinit and zstyle
# - 30-keybindings     — bindkey
# - 40-integrations    — FZF, Zoxide shell hooks
# - 50-options         — setopt flags
# - 90-p10k            — .p10k.zsh loading (must be last)
#
##############################################################################

{ ... }:

{
  imports = [
    ./10-instant-prompt.nix
    ./15-cd-dashboard.nix
    ./20-completion.nix
    ./30-keybindings.nix
    ./40-integrations.nix
    ./50-options.nix
    ./90-p10k.nix
  ];
}
