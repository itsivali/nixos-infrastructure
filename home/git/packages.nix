##############################################################################
#
# Git Packages
#
# Purpose
# -------
# Own Git-related packages installed via Home Manager.
# Only packages not already in packages/cli go here.
#
# Ownership
# ---------
# home.packages entries for Git-specific tooling
#
# Responsibilities
# ----------------
# - Git LFS (not in system packages)
#
# Does NOT Own
# ------------
# - CLI tools (packages/cli/default.nix) — includes lazygit, gitui, git, gh, glab
# - Shell packages (home/shell/tools/)
# - Editor packages (home/editors/)
# - Environment packages (home/environment/)
#
##############################################################################

{ pkgs, ... }:

{
  home.packages = with pkgs; [
    git-lfs
  ];
}
