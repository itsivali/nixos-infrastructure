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
  google-chrome

  # Communication
  zoom-us

  # Productivity
  #
  # collabora-desktop: temporarily out of the first-switch closure. It is
  # patched by lib/overlays/collabora-desktop.nix (upstream does not link
  # without 0002-fix-coda-qt-link.patch), so its hash matches nothing in
  # cache.nixos.org and it must be compiled locally — a LibreOffice-scale
  # build, hours of it on two cores, in front of everything else in the
  # rebuild. Re-enable once the machine is up and let a background rebuild
  # or the GitOps reconciler absorb the compile.
  #
  # Dropping it here does not affect the collabora-desktop-link-fix check in
  # flake.nix: that inspects pkgs.collabora-desktop.patches at eval time and
  # never builds or installs the package.
  # collabora-desktop
  obsidian
  notion-app-enhanced

  # apostrophe: also temporarily out. It depends on a *full* texlive
  # (texlive-2025-final-env), which is 250 store paths and 3.2 GiB unpacked —
  # measured as the single largest slice of the first-switch download, for a
  # markdown editor. Re-enable later, or swap for a lighter editor if the
  # LaTeX export is not actually used.
  # apostrophe

  # Media
  mpv

  # Utilities
  mission-center
  xdg-utils
]
