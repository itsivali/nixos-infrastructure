##############################################################################
#
# OpenHands — Self-Hosted AI Coding Agent
#
# Purpose
# -------
# Docker-based OpenHands setup for a self-hosted AI coding agent with
# full sandbox, browser, and shell access. Bring-your-own-key (requires
# an LLM API key like OpenAI, Anthropic, etc.).
#
# Ownership
# ---------
# virtualisation.docker, ivali.openhands options
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.openhands;
  defaultUser = config.users.users.default.name or "ivali";
in
{
  options.ivali.openhands = {
    enable = lib.mkEnableOption "OpenHands self-hosted AI coding agent";
    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Port for the OpenHands web UI";
    };
    workspaceDir = lib.mkOption {
      type = lib.types.path;
      default = "/home/${defaultUser}/projects";
      description = "Directory mounted as workspace inside OpenHands";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker.enable = lib.mkForce true;

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "openhands" ''
        CONTAINER_NAME="openhands"
        WORKSPACE="''${OPENHANDS_WORKSPACE:-${cfg.workspaceDir}}"
        PORT="''${OPENHANDS_PORT:-${toString cfg.port}}"

        ${pkgs.docker}/bin/docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

        echo "Starting OpenHands on http://localhost:$PORT"
        echo "Workspace: $WORKSPACE"
        echo ""
        echo "Note: You need an LLM API key (OPENAI_API_KEY, ANTHROPIC_API_KEY, etc.)"
        echo "Set it via: export OPENAI_API_KEY=your-key"
        echo ""

        exec ${pkgs.docker}/bin/docker run -it --rm \
          --name "$CONTAINER_NAME" \
          -p "$PORT:3000" \
          -v "$WORKSPACE:/workspace" \
          -e SANDBOX_RUNTIME_CONTAINER_IMAGE=openhands/openhands-runtime:0.9 \
          -e WORKSPACE_MOUNT_PATH="$WORKSPACE" \
          ghcr.io/all-hands-ai/openhands:0.9
      '')
    ];
  };
}
