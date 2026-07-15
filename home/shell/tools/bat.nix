##############################################################################
#
# Bat
#
# Purpose
# -------
# Own every Home Manager option related to Bat.
#
# Ownership
# ---------
# programs.bat
#
##############################################################################

{ ... }:

{
  programs.bat = {
    enable = true;
    config = {
      theme = "gruvbox-dark";
      style = "numbers,changes,header,grid";
      italic-text = "always";
    };
  };
}
