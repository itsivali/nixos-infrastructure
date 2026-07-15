##############################################################################
#
# Eza
#
# Purpose
# -------
# Own every Home Manager option related to Eza.
#
# Ownership
# ---------
# programs.eza
#
##############################################################################

{ ... }:

{
  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    git = true;
    icons = "auto";
    extraOptions = [
      "--group-directories-first"
    ];
  };
}
