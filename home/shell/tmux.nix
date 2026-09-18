##############################################################################
#
# Tmux
#
# Purpose
# -------
# Declarative tmux configuration for persistent terminal sessions.
# Enables mouse support, large history, and stable terminal type.
# Used primarily for SSH maintenance sessions.
#
# Ownership
# ---------
# programs.tmux
#
# Does NOT Own
# ------------
# - SSH auto-attach behavior (home/shell/core/zsh.nix)
# - Shell aliases (shell/aliases/)
# - Shell prompt (shell/core/prompt.nix)
#
##############################################################################

{ ... }:

{
  programs.tmux = {
    enable = true;
    mouse = true;
    historyLimit = 50000;
    escapeTime = 0;
    terminal = "tmux-256color";
    keyMode = "vi";

    extraConfig = ''
      # Window/pane numbering
      set -g base-index 1
      setw -g pane-base-index 1
      set -g renumber-windows on

      # Enable focus events for terminal multiplexing
      set -g focus-events on
    '';
  };
}
