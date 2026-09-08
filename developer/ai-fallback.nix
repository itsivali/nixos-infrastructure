##############################################################################
#
# AI Coding Agent Fallback Wrapper
#
# Purpose
# -------
# Provides an `ai` command that cascades through the available AI coding
# agents in priority order:
#
#   1. opencode — primary agent
#   2. kilo     — fallback if opencode is not found on PATH
#   3. agy      — fallback if kilo is not found on PATH
#
# This ensures uninterrupted agentic development regardless of which tool
# is available on any given machine or environment.
#
# The wrapper prints the selected tool to stderr before delegating, making
# it always clear which agent is running.
#
# Ownership
# ---------
# environment.systemPackages
#
# Dependencies
# ------------
# Intended for use alongside ivali.kilocode and ivali.antigravity being
# enabled. The wrapper degrades gracefully if any tool is absent.
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.dev.aiFallback;

  ai-wrapper = pkgs.writeShellScriptBin "ai" ''
    # ai — AI coding agent fallback wrapper
    #
    # Priority order: opencode → kilo → agy
    # Passes all arguments through to the selected agent.

    _try_agent() {
      local name="$1"
      shift
      if command -v "$name" > /dev/null 2>&1; then
        echo "[ai] using $name" >&2
        exec "$name" "$@"
      fi
    }

    _try_agent opencode "$@"
    _try_agent kilo     "$@"
    _try_agent agy      "$@"

    echo "[ai] ERROR: no AI coding agent found on PATH." >&2
    echo "[ai] Install at least one of: opencode, kilo (kilocode), agy (antigravity)" >&2
    exit 1
  '';
in
{
  options.ivali.dev.aiFallback = {
    enable = lib.mkEnableOption "AI coding agent fallback wrapper (ai command)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      ai-wrapper
    ];
  };
}
