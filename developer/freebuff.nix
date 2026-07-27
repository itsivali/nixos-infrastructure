##############################################################################
#
# Freebuff — Free AI Coding Agent
#
# Purpose
# -------
# System-wide installation of Freebuff, a terminal-based AI coding agent
# powered by open-source models (DeepSeek, Kimi, MiniMax). No API key required.
#
# Ownership
# ---------
# environment.systemPackages
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.freebuff;
in
{
  options.ivali.freebuff = {
    enable = lib.mkEnableOption "Freebuff free AI coding agent";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "freebuff" ''
        exec ${pkgs.nodejs}/bin/npx --yes freebuff "$@"
      '')
    ];
  };
}
