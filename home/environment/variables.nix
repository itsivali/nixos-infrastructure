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
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "bat";
    MANPAGER = "sh -c 'col -bx | bat -l man -p'";
    LESS = "-R";
    SOPS_AGE_KEY_FILE = "$HOME/.config/sops/age/keys.txt";
  };
}
