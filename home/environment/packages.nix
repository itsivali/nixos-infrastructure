##############################################################################
#
# User Packages
#
# Purpose
# -------
# Home Manager user packages — combines packages/user set with
# shell-specific extras (zsh plugins, monitoring, git tools).
#
# Ownership
# ---------
# home.packages
#
# Does NOT Own
# ------------
# - System-wide packages (hosts/laptop.nix, packages/system)
# - Shell tools (home/shell/tools/packages.nix)
# - Git tools (home/git/packages.nix)
#
##############################################################################

{ pkgs, ... }:

{
  home.packages = (import ../../packages/user { inherit pkgs; }) ++ (with pkgs; [
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

    # Monitoring
    btop
    fastfetch

    # Git
    lazygit
  ]);
}
