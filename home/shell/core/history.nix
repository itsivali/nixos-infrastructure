##############################################################################
#
# Zsh History
#
# Purpose
# -------
# Own Zsh history configuration.
#
# Ownership
# ---------
# programs.zsh.history
#
# Responsibilities
# ----------------
# - History size and save limits
# - History file path
# - Deduplication and ignore patterns
# - Sharing across sessions
#
# Does NOT Own
# ------------
# - Shell options like HIST_IGNORE_DUPS (shell/core/startup/50-options.nix)
#
##############################################################################

{ config, ... }:

{
  programs.zsh.history = {
    size = 100000;
    save = 100000;
    path = "${config.xdg.dataHome}/zsh/history";
    ignoreDups = true;
    ignoreSpace = true;
    share = true;
    extended = true;
  };
}
