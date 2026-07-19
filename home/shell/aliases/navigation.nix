##############################################################################
#
# Navigation Aliases
#
# Purpose
# -------
# Directory navigation and file listing aliases.
#
# Ownership
# ---------
# programs.zsh.shellAliases entries for navigation and listing
#
# Responsibilities
# ----------------
# - Directory shortcuts (.., ..., ...., home, cfg, edit)
# - Listing commands (ls, ll, la, lt, l, cat)
#
##############################################################################

{ config, ... }:

let
  repoDir = "${config.home.homeDirectory}/nixos-infrastructure";
in

{
  programs.zsh.shellAliases = {
    # Directory navigation
    ".." = "cd ..";
    "..." = "cd ../..";
    "...." = "cd ../../..";
    home = "cd ~";
    cfg = "cd ${repoDir}";
    dots = "cd ${repoDir}";
    edit = "zeditor ${repoDir}";
    z = "zeditor";

    # Listing
    ls = "eza";
    ll = "eza -lah --icons --git";
    la = "eza -a";
    lt = "eza --tree";
    l = "eza -lh";
    tree = "eza --tree";
    cat = "bat";
  };
}
