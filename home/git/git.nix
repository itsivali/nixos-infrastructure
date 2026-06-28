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
    };
  };
}