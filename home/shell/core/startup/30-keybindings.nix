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

    ######################################################################
    # Ctrl+G — open lazygit in the current git repository
    ######################################################################
    _lazygit_widget() {
      if git rev-parse --is-inside-work-tree &>/dev/null; then
        lazygit
      else
        print -P '%F{red}Not in a git repository%f'
      fi
    }
    zle -N _lazygit_widget
    bindkey '^G' _lazygit_widget
  '';
}
