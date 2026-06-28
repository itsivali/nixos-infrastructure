##############################################################################
#
# Git Aliases
#
# Purpose
# -------
# Git command shortcuts.
#
# Ownership
# ---------
# programs.zsh.shellAliases entries for Git operations
#
# Responsibilities
# ----------------
# - Basic Git commands (g, gs, ga, gaa, gc, gcm, gp, gpl)
# - Diff and log (gd, gl)
# - Branch management (gb, gco)
# - Stash (gst)
# - Full workflow (gcap)
#
##############################################################################

{ ... }:

{
  programs.zsh.shellAliases = {
    g = "git";
    gs = "git status";
    ga = "git add";
    gaa = "git add .";
    gc = "git commit";
    gcm = "git commit -m";
    gp = "git push";
    gpl = "git pull";
    gd = "git diff";
    gl = "git log --graph --decorate --oneline";
    gb = "git branch";
    gco = "git checkout";
    gst = "git stash";
    gcap = "git add . && git commit && git push";
  };
}
