##############################################################################
#
# Freebuff — Free AI Coding Agent
#
# Purpose
# -------
# System-wide installation of Freebuff, a terminal-based AI coding agent
# powered by open-source models (DeepSeek, MiMo, MiniMax, GPT-5.6).
# No API key required — ad-supported.
#
# Ownership
# ---------
# environment.systemPackages
#
##############################################################################

{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.ivali.freebuff;
  system = pkgs.stdenv.hostPlatform.system;
in
{
  options.ivali.freebuff = {
    enable = lib.mkEnableOption "Freebuff free AI coding agent";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      inputs.llm-agents.packages.${system}.freebuff
    ];
  };
}
