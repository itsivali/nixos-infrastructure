##############################################################################
#
# Automatic Nix Repository Formatting
#
# Purpose
# -------
# Watch the nixos-infrastructure repository and format changed Nix files.
#
# Ownership
# ---------
# systemd.user.services.nix-repo-auto-format
#
# Responsibilities
# ----------------
# - Watch ~/nixos-infrastructure for changes
# - Auto-format .nix files with nix fmt
# - Low CPU priority (nice 10, idle IO)
#
##############################################################################

{ config, pkgs, ... }:

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
  systemd.user.services.nix-repo-auto-format = {
    Unit = {
      Description = "Automatically format Nix files in nixos-infrastructure";
      After = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${autoFormatNix}/bin/auto-format-nix-repo";
      Restart = "on-failure";
      RestartSec = "5s";

      Nice = 10;
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 7;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
