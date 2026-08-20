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
      pkgs.llm-agents.freebuff
    ];
  };
}
