##############################################################################
#
# FZF
#
# Purpose
# -------
# Own every Home Manager option related to FZF.
#
# Ownership
# ---------
# programs.fzf
#
# Responsibilities
# ----------------
# - Enable FZF
# - Zsh shell integration
#
# Does NOT Own
# ------------
# - Shell startup sourcing of key-bindings/completion (shell/core/startup/40-integrations.nix)
#
##############################################################################

{ ... }:

{
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };
}
