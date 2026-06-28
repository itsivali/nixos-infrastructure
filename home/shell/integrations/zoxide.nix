##############################################################################
#
# Zoxide
#
# Purpose
# -------
# Own every Home Manager option related to Zoxide.
#
# Ownership
# ---------
# programs.zoxide
#
# Responsibilities
# ----------------
# - Enable Zoxide
# - Zsh shell integration
#
# Does NOT Own
# ------------
# - Shell startup eval (shell/core/startup/40-integrations.nix)
#
##############################################################################

{ ... }:

{
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
}
