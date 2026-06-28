##############################################################################
#
# Completion Startup
#
# Purpose
# -------
# Initialise Zsh completion system early in the startup sequence.
#
# Order
# -----
# After instant prompt, before key bindings.
#
##############################################################################

{ pkgs, ... }:

{
  programs.zsh.initContent = ''
    ######################################################################
    # Completion
    ######################################################################
    autoload -Uz compinit
    compinit

    zstyle ':completion:*' matcher-list \
        'm:{a-z}={A-Za-z}' \
        'r:|=*' \
        'l:|=* r:|=*'

    zstyle ':completion:*' menu select
    zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"

    ######################################################################
    # Useful completion colours
    ######################################################################
    export LS_COLORS=$(${pkgs.coreutils}/bin/dircolors -b)
  '';
}
