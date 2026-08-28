##############################################################################
#
# Kilocode CLI
#
# Purpose
# -------
# System-wide installation of Kilocode CLI, a fork of OpenCode that supports
# 500+ AI models. Provides the `kilo` command for agentic development workflows.
# Installed via npm as @kilocode/cli.
#
# Ownership
# ---------
# environment.systemPackages
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.kilocode;
in
{
  options.ivali.kilocode = {
    enable = lib.mkEnableOption "Kilocode CLI (fork of OpenCode)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.kilo
    ];
  };
}
