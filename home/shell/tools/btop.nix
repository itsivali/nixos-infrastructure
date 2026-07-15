##############################################################################
#
# Btop
#
# Purpose
# -------
# Own every Home Manager option related to Btop.
#
# Ownership
# ---------
# programs.btop
#
##############################################################################

{ ... }:

{
  programs.btop = {
    enable = true;
    settings = {
      theme_background = true;
      truecolor = true;
      proc_tree = true;
      proc_sorting = "memory";
    };
  };
}
