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

let
  # zoom.us returns 403 to non-browser user agents, which nixpkgs' plain
  # fetchurl hits and then retries forever. Send a browser UA on the source
  # fetch only; the pinned hash in nixpkgs stays authoritative.
  zoom-us = pkgs.zoom-us.override {
    fetchurl = args: pkgs.fetchurl (args // {
      curlOptsList = [
        "-A"
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
      ];
    });
  };
in

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
  gnome-tweaks
  xdg-utils
]
