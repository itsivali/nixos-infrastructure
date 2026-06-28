##############################################################################
#
# Powerlevel10k Configuration Loader
#
# Purpose
# -------
# Load the user's custom Powerlevel10k configuration file.
#
# Order
# -----
# Must run last — after all other startup fragments.
#
##############################################################################

{ ... }:

{
  programs.zsh.initContent = ''
    ######################################################################
    # Load user Powerlevel10k configuration
    ######################################################################
    [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
  '';
}
