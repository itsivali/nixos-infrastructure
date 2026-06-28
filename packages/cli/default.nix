# packages/cli/default.nix
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
  gh
  git
  gitui
  gitlab
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
  ripgrep
  rsync
  sops
  starship
  tree
  unzip
  usbutils
  vim
  watchexec
  wget
  zoxide
]
