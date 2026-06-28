##############################################################################
#
# Git Module
#
# Purpose
# -------
# Compose all Git-related Home Manager modules.
#
# This file should never contain configuration.
# It exists solely to compose child modules.
#
##############################################################################

{ ... }:

{
  imports = [
    ./packages.nix
    ./git.nix
    ./delta.nix
  ];
}