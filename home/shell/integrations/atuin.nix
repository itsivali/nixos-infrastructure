##############################################################################
#
# Atuin
#
# Purpose
# -------
# Own every Home Manager option related to Atuin.
#
# Ownership
# ---------
# programs.atuin
#
##############################################################################

{ ... }:

{
  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      auto_sync = false;
      update_check = false;
      style = "compact";
    };
  };
}
