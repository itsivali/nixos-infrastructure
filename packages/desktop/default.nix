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
  brightnessctl
  gnome-screenshot
  xdg-utils
  gnome-disk-utility
  gnome-terminal
  gnome-system-monitor
  notion-app-enhanced
]
