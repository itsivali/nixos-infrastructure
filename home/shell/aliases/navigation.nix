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
# - Directory shortcuts (.., ..., ...., home, cfg, edit, repo)
# - Listing commands (ls, ll, la, lt, l, tree, cat)
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
    repo = "cd ${repoDir}";
    edit = "zeditor ${repoDir}";
    z = "zeditor";

    # Listing
    ls = "eza";
    ll = "eza -lah --icons --git --group-directories-first";
    la = "eza -a";
    lt = "eza --tree --level=2";
    l = "eza -lh";
    tree = "eza --tree --level=3";
    cat = "bat --paging=never";
  };
}
