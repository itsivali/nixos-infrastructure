##############################################################################
#
# Zsh Prompt
#
# Purpose
# -------
# Own Zsh prompt and plugin configuration.
#
# Ownership
# ---------
# - Powerlevel10k (as a plugin)
# - Zsh plugins list
# - Prompt initialisation
#
# Does NOT Own
# ------------
# - Key bindings (shell/core/keybindings.nix)
# - Completion (shell/core/completion.nix)
# - initContent for p10k config loading — lives in shell/core/startup/90-p10k.nix
#
##############################################################################

{ pkgs, ... }:

{
  programs.zsh.plugins = [
    {
      name = "powerlevel10k";
      src = pkgs.zsh-powerlevel10k;
      file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
    }
    {
      name = "zsh-completions";
      src = pkgs.zsh-completions;
    }
  ];

  # Powerlevel10k replaces Starship.
  programs.starship.enable = false;
}
