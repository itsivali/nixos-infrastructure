##############################################################################
#
# Home Manager Composition Root
#
# Purpose
# -------
# Compose all Home Manager modules.
#
# This file contains imports only.
#
##############################################################################

{ ... }:

{
  imports = [
    ./identity

    ./fonts.nix

    ./shell
    ./git
    ./environment
    ./editors
    ./services
    ./hyde
  ];
}
