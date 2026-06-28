##############################################################################
#
# Direnv
#
# Purpose
# -------
# Own every Home Manager option related to Direnv.
#
# Ownership
# ---------
# programs.direnv
#
# Responsibilities
# ----------------
# - Enable direnv
# - nix-direnv integration
#
# Does NOT Own
# ------------
# - Shell startup hooks (shell/core/startup/)
#
##############################################################################

{ ... }:

{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
