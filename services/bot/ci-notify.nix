##############################################################################
#
# CI Notification Service
#
# Purpose
# -------
# Sends CI pipeline notifications to Telegram on deploy events.
#
# Ownership
# ---------
# systemd.services.ci-notify
#
# Dependencies
# ------------
# Declares own fleet.bot.ciNotify.enable option.
# Wired in lib/host-templates/laptop.nix from hasGitLabRunner feature.
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.fleet.bot.ciNotify;
in
{
  options.fleet.bot.ciNotify = {
    enable = lib.mkEnableOption "CI pipeline notifications to Telegram";
  };

  config = lib.mkIf cfg.enable {

    systemd.services.ci-notify = {
      description = "CI Pipeline Notification";

      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      path = with pkgs; [
        bash
        coreutils
        curl
        jq
        git
      ];

      environment = {
        HOST_NAME = config.networking.hostName;
        REPO_DIR = "/home/ivali/nixos-infrastructure";
      };

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        Group = "root";
        ExecStart = "${pkgs.writeShellScript "ci-notify" ''
          set -Eeuo pipefail

          if [[ -f /tmp/ci-notify.env ]]; then
            source /tmp/ci-notify.env
            rm -f /tmp/ci-notify.env
          else
            PIPELINE_STATUS=success
          fi

          MSG="*Pipeline: ${config.networking.hostName}*
          Branch: ''${PIPELINE_BRANCH:-unknown}
          Commit: ''${PIPELINE_SHA:-unknown}
          Author: ''${PIPELINE_AUTHOR:-unknown}
          Message: ''${PIPELINE_MESSAGE:-unknown}
          Status: ''${PIPELINE_STATUS:-success}
          URL: ''${PIPELINE_URL:-unknown}"

          NOTIFY="${toString ../../scripts/notify.sh}"
          if [[ -x "$NOTIFY" ]]; then
            "$NOTIFY" "$MSG"
          fi
        ''}";
        TimeoutStartSec = "30s";
        StandardOutput = "journal";
        StandardError = "journal";
        SyslogIdentifier = "ci-notify";

        NoNewPrivileges = true;
        PrivateTmp = true;
      };
    };

  };
}
