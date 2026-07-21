##############################################################################
#
# Developer Shell
#
# Purpose
# -------
# System-level shell defaults for the developer workstation.
# Home Manager owns the interactive shell configuration.
#
# Note: programs.zsh.promptInit is set to "" to disable the NixOS-level
# prompt setup (promptinit && prompt suse) which interferes with the
# Home Manager starship prompt, causing a double prompt. Home Manager
# handles all interactive zsh config including prompt, completion, and
# plugins.
#
# Ownership
# ---------
# users.defaultUserShell, programs.zsh.enable, programs.bash.completion
#
# Does NOT Own
# ------------
# - Interactive shell config (home/shell/)
# - Docker (virtualization/docker.nix)
# - Language toolchains (developer/languages.nix)
#
##############################################################################

{ pkgs, ... }:

{
  users.defaultUserShell = pkgs.zsh;
  programs.zsh.enable = true;
  programs.zsh.promptInit = "";
  programs.bash.completion.enable = true;
}
