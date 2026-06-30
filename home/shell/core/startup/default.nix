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
# - 10-dashboard       — Fastfetch system info on terminal open
# - 15-cd-dashboard    — ivali status on cd into repo
# - 20-completion      — Completion styles (compinit handled by HM)
# - 30-keybindings     — bindkey
# - 50-options         — setopt flags
#
##############################################################################

{ ... }:

{
  imports = [
    ./10-dashboard.nix
    ./15-cd-dashboard.nix
    ./20-completion.nix
    ./30-keybindings.nix
    ./50-options.nix
  ];
}
