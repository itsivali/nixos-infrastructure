##############################################################################
#
# Environment Variables
#
# Purpose
# -------
# Future home for additional environment configuration.
#
# Examples
# --------
# • PATH additions
# • home.sessionPath
# • Custom exports
# • Development environment variables
#
##############################################################################

{ ... }:

{
  home.sessionVariables = {
    EDITOR = "zeditor --wait";
    VISUAL = "zeditor --wait";
    PAGER = "bat";
    MANPAGER = "sh -c 'col -bx | bat -l man -p'";
    LESS = "-R";
  };
}
