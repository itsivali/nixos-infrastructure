# packages/desktop/default.nix
# Desktop applications — combined into system package set by aggregator.
{ pkgs }:

with pkgs; [
  localsend
  zoom-us
  obsidian
  vlc
  firefox
  libreoffice-fresh
  stremio-linux-shell
]
