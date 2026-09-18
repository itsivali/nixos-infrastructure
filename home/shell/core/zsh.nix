##############################################################################
#
# Zsh
#
# Purpose
# -------
# Own the root Zsh shell definition.
#
# Ownership
# ---------
# programs.zsh
#
# Responsibilities
# ----------------
# - Enable Zsh
# - autocd
# - Syntax highlighting
# - Autosuggestion
# - Completion enablement
#
# Does NOT Own
# ------------
# - Aliases (shell/aliases/)
# - History (shell/core/history.nix)
# - Completion styles (shell/core/completion.nix)
# - Key bindings (shell/core/keybindings.nix)
# - Prompt / plugins (shell/core/prompt.nix)
# - Startup sequence (shell/core/startup/)
#
##############################################################################

{ config, ... }:

{
  programs.zsh = {
    enable = true;
    autocd = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    initContent = ''
      # Auto-attach tmux on interactive SSH sessions.
      # Only triggers when:
      #   - SSH_TTY is set (interactive SSH, not scp/sftp/automation)
      #   - Not already inside tmux
      #   - Shell is interactive
      # Non-interactive SSH commands (ssh host 'cmd') are unaffected.
      if [[ -n "$SSH_TTY" && -z "$TMUX" && -o interactive ]]; then
          exec tmux new-session -A -s maintenance
      fi
    '';
  };
}
