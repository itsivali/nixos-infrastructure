##############################################################################
#
# Key Bindings Startup
#
# Purpose
# -------
# Set Zsh key bindings.
#
# Order
# -----
# After completion, before integrations.
#
##############################################################################

{ ... }:

{
  programs.zsh.initContent = ''
    ######################################################################
    # Better key bindings
    ######################################################################
    bindkey '^I' menu-expand-or-complete
    bindkey '^[[A' up-line-or-search
    bindkey '^[[B' down-line-or-search
  '';
}
