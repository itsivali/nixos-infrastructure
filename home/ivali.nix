# home/ivali.nix
#
# Home Manager identity and top-level configuration.
#
# This file contains only:
# - Home identity (username, homeDirectory, stateVersion)
# - Home Manager enablement
# - Systemd user services that don't belong to a specific module
#
# All functional configuration lives in dedicated modules:
#   - shell/   — Shell environments, tools, integrations, aliases
#   - git/     — Git configuration
#   - editors/ — Editor configuration (Zed)
#   - environment/ — Environment variables, locale, XDG
#   - services/ — User services (auto-format, etc.)
#   - fonts.nix — Font configuration

{ config, lib, pkgs, username, ... }:

let
  repoDir = "${config.home.homeDirectory}/nixos-infrastructure";

  autoFormatNix = pkgs.writeShellApplication {
    name = "auto-format-nix-repo";

    runtimeInputs = with pkgs; [
      bash
      git
      nix
      watchexec
    ];

    text = ''
      set -euo pipefail

      repo="${repoDir}"

      if [ ! -d "$repo" ]; then
        echo "Repository not found: $repo"
        exec sleep infinity
      fi

      exec watchexec \
        --watch "$repo" \
        --ignore "$repo/.git" \
        --debounce 1000ms \
        --restart \
        -- bash -lc \
        "cd \"$repo\" && nix --extra-experimental-features 'nix-command flakes' fmt"
    '';
  };

in
{
  ##############################################################################
  # Home
  ##############################################################################

  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "26.11";
  };

  ##############################################################################
  # Home Manager
  ##############################################################################

  programs.home-manager.enable = true;
  home.enableNixpkgsReleaseCheck = false;

  ##############################################################################
  # Automatic Nix Repository Formatting
  ##############################################################################

  systemd.user.services.nix-repo-auto-format = {
    Unit = {
      Description = "Automatically format Nix files in nixos-infrastructure";
      After = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${autoFormatNix}/bin/auto-format-nix-repo";
      Restart = "on-failure";
      RestartSec = "5s";

      # Lower CPU priority so formatting never interferes with normal work.
      Nice = 10;
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 7;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
