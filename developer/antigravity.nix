##############################################################################
#
# Antigravity — Google Antigravity CLI
#
# Purpose
# -------
# System-wide installation of Google Antigravity CLI (agy), successor to
# Gemini CLI. Free tier uses Google OAuth — no API key required. Provides
# the `agy` command for agentic development workflows.
#
# Ownership
# ---------
# environment.systemPackages
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
