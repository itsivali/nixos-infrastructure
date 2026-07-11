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
