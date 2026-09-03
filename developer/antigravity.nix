##############################################################################
#
# Antigravity — Google Antigravity CLI
#
# Purpose
# -------
# System-wide installation of Google Antigravity CLI (agy), successor to
# Gemini CLI. Free tier uses Google OAuth — no API key required. Provides
# the `agy` command for agentic development workflows.
# Wrapped in buildFHSEnv since it's a pre-built dynamically linked binary.
#
# Ownership
# ---------
# environment.systemPackages
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.antigravity;

  antigravity-fhs = pkgs.buildFHSEnv {
    name = "agy";
    targetPkgs = pkgs: [
      pkgs.antigravity-cli
    ];
    runScript = "agy";
  };
in
{
  options.ivali.antigravity = {
    enable = lib.mkEnableOption "Google Antigravity CLI (agy)";
    package = lib.mkOption {
      type = lib.types.package;
      default = antigravity-fhs;
      readOnly = true;
      description = "The antigravity FHS package (for caching)";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
    ];
  };
}
