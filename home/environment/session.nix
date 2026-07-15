##############################################################################
#
# Session Configuration
#
# Purpose
# -------
# PATH additions and session-level configuration.
#
# Ownership
# ---------
# home.sessionPath
#
##############################################################################

{ ... }:

{
  home.sessionPath = [
    "$HOME/.local/bin"
  ];
}
