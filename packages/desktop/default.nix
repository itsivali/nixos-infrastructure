##############################################################################
#
# Packages Desktop
#
# Purpose
# -------
# Defines the set of desktop applications (Firefox, VLC, LibreOffice,
# Obsidian, Zoom, etc.) included in the system package set.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Provide a curated list of desktop application packages
# - Be importable by the system package aggregator
#
##############################################################################

# Desktop applications — combined into system package set by aggregator.
{ pkgs }:

with pkgs; [
  localsend
  zoom-us
  obsidian
  mpv
  firefox
  libreoffice-fresh
  brightnessctl
  xdg-utils
  mission-center
  notion-app-enhanced
]
