##############################################################################
#
# Nix Development Tools
#
# Purpose
# -------
# Nix language formatter, LSP, and development utilities for working
# with Nix expressions and this NixOS infrastructure repository.
#
# Ownership
# ---------
# environment.systemPackages for Nix tooling
#
##############################################################################

{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    alejandra
    nixd
    nil
  ];
}
