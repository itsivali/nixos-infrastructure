##############################################################################
#
# Packages
#
# Purpose
# -------
# TODO
#
# Owns
# ----
# TODO
#
# Rules
# -----
# • One concern only.
# • Keep this module focused.
# • If this file exceeds ~150 lines, split it.
#
##############################################################################

{ pkgs, ... }:

{
  packages = (import ../packages/user { inherit pkgs; }) ++ (with pkgs; [
    # Shell
    zsh-powerlevel10k
    zsh-completions

    # Better CLI
    eza
    bat
    fd
    ripgrep
    tree
    fzf
    delta

    # Monitoring
    btop
    fastfetch

    # Git
    lazygit
  ]);
}
