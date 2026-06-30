##############################################################################
#
# Shell Options
#
# Purpose
# -------
# Set Zsh shell options (setopt).
#
# Order
# -----
# After key bindings, before completion.
#
# Does NOT Own
# ------------
# - programs.zsh.history options (history.nix)
#
##############################################################################

{ ... }:

{
  programs.zsh.initContent = ''
    ######################################################################
    # Handy options
    ######################################################################
    setopt AUTO_CD
    setopt AUTO_PUSHD
    setopt PUSHD_IGNORE_DUPS
    setopt HIST_IGNORE_DUPS
    setopt HIST_IGNORE_SPACE
    setopt HIST_VERIFY
    setopt SHARE_HISTORY
    setopt EXTENDED_HISTORY
    setopt INC_APPEND_HISTORY
  '';
}
