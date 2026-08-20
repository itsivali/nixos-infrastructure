##############################################################################
#
# Antigravity — Google Antigravity CLI
#
# Purpose
# -------
# Install and configure Google Antigravity CLI (agy) — a terminal-based
# AI coding agent from Google, successor to Gemini CLI. Provides the `agy`
# command for agentic development workflows.
#
# Ownership
# ---------
# environment.systemPackages
#
# Does NOT Own
# ------------
# - Editor configuration (home/editors/)
# - Language servers (developer/languages.nix)
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.antigravity;
in
{
  options.ivali.antigravity = {
    enable = lib.mkEnableOption "Google Antigravity CLI (agy)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.antigravity-cli
    ];
  };
}
