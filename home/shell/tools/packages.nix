##############################################################################
#
# Shell Packages
#
# Purpose
# -------
# Own shell-related packages installed via Home Manager.
#
# Ownership
# ---------
# home.packages entries for shell tools
#
# Responsibilities
# ----------------
# - fzf
# - zoxide
# - eza
# - bat
# - btop
# - fastfetch
# - (and other shell tool packages)
#
# Does NOT Own
# ------------
# - Git packages (home/git/)
# - Editor packages (home/editors/)
# - Environment packages (home/environment/)
# - GUI packages (packages/gui/)
# - Developer packages (home/developer/)
#
##############################################################################

{ pkgs, ... }:

{
  home.packages = with pkgs; [
    bat
    btop
    eza
    fastfetch
    fd
    fzf
    ripgrep
    zoxide
  ];
}
