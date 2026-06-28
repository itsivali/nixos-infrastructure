##############################################################################
#
# Integrations Startup
#
# Purpose
# -------
# Load shell integrations for FZF and Zoxide.
#
# Order
# -----
# After key bindings, before shell options.
#
##############################################################################

{ pkgs, ... }:

{
  programs.zsh.initContent = ''
    ######################################################################
    # FZF
    ######################################################################
    source ${pkgs.fzf}/share/fzf/key-bindings.zsh
    source ${pkgs.fzf}/share/fzf/completion.zsh

    ######################################################################
    # Zoxide
    ######################################################################
    eval "$(zoxide init zsh)"
  '';
}
