##############################################################################
#
# User Packages
#
# Purpose
# -------
# Home Manager user packages — imports the packages/user set which
# includes all CLI tools. Shell-specific extras (zsh plugins) go here.
#
# Ownership
# ---------
# home.packages
#
# Does NOT Own
# ------------
# - System-wide packages (packages/cli, packages/system)
# - Shell tool configs (home/shell/tools/*.nix)
# - Git tool configs (home/git/*.nix)
# - Editor packages (home/editors/)
#
##############################################################################

{ pkgs, ... }:

{
  home.packages = (import ../../packages/user { inherit pkgs; }) ++ (with pkgs; [
    # Zsh plugins (not in system packages)
    zsh-completions
  ]);
}
