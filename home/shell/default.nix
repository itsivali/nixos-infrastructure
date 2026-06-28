##############################################################################
#
# Home Manager Shell Configuration Module Root
#
# Purpose
# -------
# Aggregates and loads all command line utilities, shell environments, 
# and interactive tools.
#
##############################################################################

{ ... }:

{
  imports = [
    ./aliases.nix
    ./atuin.nix
    ./bash.nix
    ./bat.nix
    ./bitwarden.nix
    ./btop.nix
    ./direnv.nix
    ./eza.nix
    ./fastfetch.nix
    ./fzf.nix
    ./zoxide.nix
    ./zsh.nix
  ];
}