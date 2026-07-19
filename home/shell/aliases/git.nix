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
    gpo = "git push origin";
    gph = "git push github";
    gpall = "git push origin main && git push github main";
    gpl = "git pull";
    gplr = "git pull --rebase";
    gd = "git diff";
    gds = "git diff --staged";
    gl = "git log --graph --decorate --oneline";
    glog = "git log --oneline --graph --decorate -15";
    gb = "git branch";
    gco = "git checkout";
    gsw = "git switch";
    gmain = "git switch main";
    gst = "git stash";
    gstp = "git stash pop";
    gundo = "git reset --soft HEAD~1";
    gcap = "git add . && git commit && git push";
  };
}
