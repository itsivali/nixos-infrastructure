##############################################################################
#
# Powerlevel10k Instant Prompt
#
# Purpose
# -------
# Load Powerlevel10k's instant prompt for faster shell startup.
#
# Order
# -----
# Must run first — before anything that produces output.
#
##############################################################################

{ ... }:

{
  programs.zsh.initContent = ''
    ######################################################################
    # Powerlevel10k Instant Prompt
    ######################################################################
    if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${USER}.zsh" ]]; then
      source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${USER}.zsh"
    fi
  '';
}
