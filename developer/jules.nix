##############################################################################
#
# Jules — Google AI Coding Agent
#
# Purpose
# -------
# System-wide installation of the Google Jules CLI, an async AI coding agent
# powered by Gemini that creates PRs on GitHub via cloud VMs.
#
# Ownership
# ---------
# environment.systemPackages
#
# Does NOT Own
# ------------
# - GNOME launcher (home/gnome/launchers.nix)
# - Shell aliases (home/shell/aliases/development.nix)
# - Dashboard integration (internal/commands/dashboard.go)
# - Telegram commands (internal/telegram/handlers/jules_commands.go)
# - SOPS secrets (security/sops.nix)
#
##############################################################################

{ config, lib, pkgs, self, ... }:

let
  cfg = config.ivali.jules;
in
{
  options.ivali.jules = {
    enable = lib.mkEnableOption "Google Jules AI coding agent";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      self.packages.${pkgs.stdenv.hostPlatform.system}.jules
    ];

    # SOPS secret for the API key — owned by ivali so the Jules wrapper can read it
    sops.secrets.jules-api-key = {
      sopsFile = ../secrets/jules.yaml;
      path = "/run/secrets/jules-api-key";
      owner = "ivali";
    };
  };
}
