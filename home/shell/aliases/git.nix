##############################################################################
#
# Git Aliases
#
# Purpose
# -------
# Git command shortcuts for the standard workflow.
#
# Ownership
# ---------
# programs.zsh.shellAliases entries for Git operations
#
# Responsibilities
# ----------------
# - Status and diff (gs, gd, gds, gss)
# - Add and commit (ga, gaa, gc, gcm, gcmsg, gcap)
# - Push and pull (gp, gpo, gph, gpall, gpl, gplr, gf)
# - Log and graph (gl, glog, gsh)
# - Branch and checkout (gb, gco, gsw, gmain)
# - Stash (gst, gstp)
# - Cleanup (gclean)
# - Undo (gundo)
#
##############################################################################

{ ... }:

{
  programs.zsh.shellAliases = {
    # Status and diff
    gs = "git status";
    gss = "git status -s";
    gd = "git diff";
    gds = "git diff --staged";
    gdw = "git diff --stat";

    # Add and commit
    ga = "git add";
    gaa = "git add .";
    gau = "git add -u";
    gc = "git commit";
    gcm = "git commit -m";
    gcmsg = "git commit --allow-empty-message -m ''";
    gca = "git commit --amend";
    gcap = "git add . && git commit && git push";

    # Push and pull
    gp = "git push";
    gpo = "git push origin";
    gph = "git push github";
    gpall = "git push origin main && git push github main";
    gpl = "git pull";
    gplr = "git pull --rebase";
    gf = "git fetch --all --prune";

    # Log and graph
    gl = "git log --graph --decorate --oneline";
    glog = "git log --oneline --graph --decorate -20";
    gsh = "git log --oneline -10";

    # Branch and checkout
    gb = "git branch";
    gba = "git branch -a";
    gco = "git checkout";
    gsw = "git switch";
    gmain = "git switch main";
    gdco = "git checkout -- .";

    # Stash
    gst = "git stash";
    gstp = "git stash pop";
    gstl = "git stash list";

    # Cleanup
    gclean = "git clean -fd";

    # Undo
    gundo = "git reset --soft HEAD~1";
    ghard = "git reset --hard HEAD";

    # Misc
    gr = "git remote -v";
    gpr = "git pull --rebase origin main";
  };
}
