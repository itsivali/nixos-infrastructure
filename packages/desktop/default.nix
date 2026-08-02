################################################################################
# Desktop Packages
#
# Purpose:
#   Defines the desktop applications installed system-wide.
#
# Responsibilities:
#   - Provide a curated set of desktop applications.
#   - Be imported by the system package aggregator.
#
# Owner:
#   Willis Ivali
################################################################################

{ pkgs, ... }:

with pkgs; [
  # Web Browsers
  firefox
  microsoft-edge

  # Communication
  zoom-us

  # Productivity
  libreoffice-fresh
  obsidian
  notion-app-enhanced

  # Media
  mpv

  # Utilities
  brightnessctl
  localsend
  mission-center
  xdg-utils
]
