##############################################################################
#
# Bash
#
# Purpose
# -------
# Own every Home Manager option related to Bash.
#
# Ownership
# ---------
# programs.bash
#
# Responsibilities
# ----------------
# - Enable Bash
# - Enable completion
#
# Does NOT Own
# ------------
# - Aliases (shell/aliases/)
# - Environment variables (home/environment/)
# - Packages (shell/tools/packages.nix)
#
##############################################################################

{ ... }:

{
  programs.bash = {
    enable = true;
    enableCompletion = true;
  };
}
