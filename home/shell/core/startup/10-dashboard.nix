##############################################################################
#
# Startup Dashboard
#
# Purpose
# -------
# Show a pretty system info dashboard (fastfetch) on terminal open,
# but only once per session to avoid spam on every new tab.
#
# Order
# -----
# First — before anything that produces other output.
#
##############################################################################

{ pkgs, ... }:

{
  programs.zsh.initContent = ''
    ######################################################################
    # System dashboard — fastfetch on first terminal of each session
    ######################################################################
    if [[ -z "$FASTFETCH_SHOWN" ]] && [[ -z "$SSH_TTY" ]] && [[ $TERM != "dumb" ]]; then
      export FASTFETCH_SHOWN=1
      ${pkgs.fastfetch}/bin/fastfetch
    fi
  '';
}