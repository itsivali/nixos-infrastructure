##############################################################################
#
# Channel Bump — automated nixpkgs (unstable) PR
#
# Purpose
# -------
# Staying current on nixos-unstable is otherwise a manual chore.
# On a schedule this opens a Merge Request that bumps the pinned
# nixpkgs commit (via `nix flake update`), so CI validates it
# and the GitOps reconciler deploys it once merged.
#
# Ownership
# ---------
# fleet.channels.bump.*, systemd channel-bump.{service,timer}
#
# Dependencies
# ------------
# Requires SOPS secret: secrets/gitlab.yaml -> gitlab_api_token
# (used for the GitLab MR API call). Pushes via the operator's
# SSH key, exactly like the reconciler (GIT_SSH_COMMAND).
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.fleet.channels.bump;
  repo = "/home/ivali/nixos-infrastructure";

  bumpScript = pkgs.writeShellScript "channel-bump" ''
    #!/bin/sh
    set -eu

    cd "${repo}"
    if ! git diff --quiet; then
      echo "dirty working tree; skipping bump"
      exit 0
    fi

    BEFORE="$(sha256sum flake.lock)"
    nix flake update --update-input nixpkgs || { echo "flake update failed; skipping"; exit 0; }
    AFTER="$(sha256sum flake.lock)"
    if [ "$BEFORE" = "$AFTER" ]; then
      echo "nixpkgs already current; nothing to do"
      exit 0
    fi

    DATE="$(date +%Y%m%d)"
    BR="bump-nixpkgs-$DATE"
    git checkout -b "$BR"
    git add flake.lock
    git commit -q -m "chore: bump nixpkgs (unstable)"
    git push -u origin "$BR"

    TOKEN="$(cat /run/secrets/gitlab_api_token)"
    PROJ="willisivali%2Fnixos-infrastructure"
    curl -fsS -X POST \
      "https://gitlab.com/api/v4/projects/$PROJ/merge_requests" \
      --header "PRIVATE-TOKEN: $TOKEN" \
      --data-urlencode "source_branch=$BR" \
      --data-urlencode "target_branch=main" \
      --data-urlencode "title=chore: bump nixpkgs (unstable)" \
      --data "remove_source_branch=true" \
      || echo "MR creation failed (branch $BR pushed; open manually)"

    echo "opened channel-bump MR for $BR"
  '';
in
{
  options.fleet.channels.bump = {
    enable = lib.mkEnableOption "automated nixpkgs channel-bump MR";

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "weekly";
      example = "Mon *-*-* 06:00:00";
      description = "systemd OnCalendar for the bump timer.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets.gitlab_api_token = {
      sopsFile = ../secrets/gitlab.yaml;
      owner = "root";
      mode = "0400";
    };

    environment.systemPackages = [ pkgs.git pkgs.curl pkgs.nix ];

    systemd.services.channel-bump = {
      description = "Bump nixpkgs and open a GitLab MR";
      # Reuse the operator's passphrase-less deploy key, like the reconciler.
      environment.GIT_SSH_COMMAND = "ssh -i /home/ivali/.ssh/id_ed25519 -o UserKnownHostsFile=/home/ivali/.ssh/known_hosts -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        TimeoutStartSec = "300s";
      };
      path = with pkgs; [ bash coreutils git curl nix openssh util-linux inetutils ];
      script = ''
        exec ${bumpScript}
      '';
    };

    systemd.timers.channel-bump = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
      };
    };
  };
}
