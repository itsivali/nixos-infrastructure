##############################################################################
#
# Completion Startup
#
# Purpose
# -------
# Configure Zsh completion styles early in the startup sequence.
# compinit is automatically invoked by Home Manager (enableCompletion).
#
# Order
# -----
# After dashboard, before key bindings.
#
##############################################################################

{ pkgs, ... }:

{
  programs.zsh.initContent = ''
    ######################################################################
    # Completion styles
    ######################################################################
    zstyle ':completion:*' matcher-list \
        'm:{a-z}={A-Za-z}' \
        'r:|=*' \
        'l:|=* r:|=*'

    zstyle ':completion:*' menu select
    zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"

    ######################################################################
    # LS colours
    ######################################################################
    export LS_COLORS=$(${pkgs.coreutils}/bin/dircolors -b)
  '';
}
