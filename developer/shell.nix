##############################################################################
#
# Developer Shell
#
# Purpose
# -------
# System-level shell defaults for the developer workstation.
# Home Manager owns the interactive shell configuration.
#
# Ownership
# ---------
# users.defaultUserShell, programs.zsh.enable, programs.bash.completion
#
# Does NOT Own
# ------------
# - Interactive shell config (home/shell/)
# - Docker (developer/docker.nix)
# - Language toolchains (developer/languages.nix)
#
##############################################################################

{ pkgs, ... }:

{
  users.defaultUserShell = pkgs.zsh;
  programs.zsh.enable = true;
  programs.bash.completion.enable = true;
}
