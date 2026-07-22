##############################################################################
#
# Google Antigravity IDE
#
# Purpose
# -------
# Install and configure Google Antigravity — an agentic development platform
# by Google. Provides the IDE (VS Code fork with AI agents), the CLI (agy),
# and the base orchestration app. Auto-updating via the antigravity-nix flake.
#
# Ownership
# ---------
# environment.systemPackages, xdg desktop entries
#
# Does NOT Own
# ------------
# - Editor configuration (home/editors/)
# - Language servers (developer/languages.nix)
#
##############################################################################

{ config, lib, pkgs, inputs, ... }:

let
  antigravityPkgs = inputs.antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  config = {
    environment.systemPackages = [
      antigravityPkgs.google-antigravity-ide
      antigravityPkgs.google-antigravity-cli
    ];

    # Allow Antigravity to use Chromium sandbox on NixOS
    nixpkgs.config.allowUnfree = true;
  };
}
