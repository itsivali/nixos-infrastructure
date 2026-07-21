##############################################################################
#
# Developer Shell
#
# Purpose
# -------
# System-level shell defaults for the developer workstation.
# Home Manager owns the interactive shell configuration.
#
# Note: programs.zsh.enable is intentionally NOT set here. The NixOS-level
# zsh init runs `promptinit && prompt suse` which interferes with the
# Home Manager starship prompt, causing a double prompt. Home Manager
# handles all interactive zsh config including prompt, completion, and
# plugins.
#
# Ownership
# ---------
# users.defaultUserShell, programs.bash.completion
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
  programs.bash.completion.enable = true;
}
