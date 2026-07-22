##############################################################################
#
# Packages CLI
#
# Purpose
# -------
# Defines the set of CLI tools included in the system and user package sets
# (age, bat, btop, git, fzf, ripgrep, neovim, etc.).
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Provide a curated list of CLI packages for development and operations
# - Be importable by system and user package aggregators
#
##############################################################################

# CLI tools — combined into system/user package sets by aggregators.
{ pkgs }:

with pkgs; [
  age
  bat
  bitwarden-cli
  btop
  curl
  direnv
  eza
  fastfetch
  fd
  fzf
  grim
  gh
  git
  gitui
  gitlab
  glab
  gnupg
  home-manager
  htop
  iproute2
  jq
  just
  lazygit
  nixd
  opencode
  openssl
  pciutils
  python3
  ripgrep
  rsync
  sops
  starship
  sysstat
  tree
  unzip
  usbutils
  vim
  watchexec
  wmctrl
  wget
  zoxide
]
