##############################################################################
#
# Git Packages
#
# Purpose
# -------
# Own Git-related packages installed via Home Manager.
#
# Ownership
# ---------
# home.packages entries for Git tooling
#
# Responsibilities
# ----------------
# - Git LFS
# - GitUI
# - LazyGit
#
# Does NOT Own
# ------------
# - Shell packages (home/shell/tools/packaes.nix)
# - Editor packages (home/editors/)
# - Environment packages (home/environment/)
#
##############################################################################

{ pkgs, ... }:

{
  home.packages = with pkgs; [
    git-lfs
    gitui
    lazygit
  ];
}
