##############################################################################
#
# Utility Aliases
#
# Purpose
# -------
# General shell utility aliases.
#
# Ownership
# ---------
# programs.zsh.shellAliases entries for general utilities
#
# Responsibilities
# ----------------
# - Clear screen (cls)
# - History (h)
#
##############################################################################

{ ... }:

{
  programs.zsh.shellAliases = {
    cls = "clear";
    h = "history";
  };
}
