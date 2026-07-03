##############################################################################
#
# Git Configuration
#
# Purpose
# -------
# Configure Git defaults for the development workstation.
#
##############################################################################

{ ... }:

{
  programs.git = {
    enable = true;

    lfs.enable = true;

    ignores = [
      ".DS_Store"
      "*.swp"
      "*.tmp"
      "result"
      "nodemodules"
      ".gitignore"
    ];

    settings = {
      user = {
        name = "Willis Ivali";
        email = "itsivali@outlook.com";
      };

      init.defaultBranch = "main";

      pull.rebase = true;
      push.autoSetupRemote = true;

      fetch.prune = true;

      rerere.enabled = true;

      core.editor = "zeditor --wait";

      color.ui = true;

      merge.conflictstyle = "zdiff3";

      # Push to both GitLab and GitHub via the 'all' remote
      push.default = "current";
    };
  };

  # Configure the 'all' remote to push to both GitLab and GitHub
  # Usage: git push all main   (pushes to both remotes)
  #        git push             (pushes to origin only)
  #        git pushall          (alias for git push all main)
}