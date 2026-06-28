##############################################################################
#
# Git Delta
#
# Purpose
# -------
# Configure Git Delta as the default diff and pager.
#
# Ownership
# ---------
# programs.delta
#
# Does NOT Own
# ------------
# - Git configuration (home/git/git.nix)
# - Git packages (home/git/packages.nix)
#
##############################################################################

{ ... }:

{
  programs.delta = {
    enable = true;

    options = {
      features = "side-by-side line-numbers decorations";
      syntax-theme = "gruvbox-dark";
      line-numbers = true;
      side-by-side = true;
      navigate = true;
      light = false;
    };
  };
}
