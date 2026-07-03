{ config, lib, pkgs, ... }:

let
  botScript =
    if builtins.pathExists ../../scripts/bot/bot.sh then
      ../../scripts/bot/bot.sh
    else if builtins.pathExists ../../scripts/bot.sh then
      ../../scripts/bot.sh
    else
      throw ''
        Missing:

          scripts/bot/bot.sh
      '';

  botCfg = config.fleet.bot;
  runnerCfg = config.fleet.gitlabRunner;
in
{
  config = lib.mkMerge [

    ##########################################################################
    ## Telegram Bot — gated on fleet.bot.enable
    ##########################################################################

    (lib.mkIf botCfg.enable {

      systemd.services.ivali-bot = {
        description = "Telegram Bot Control Plane";

        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        wantedBy = [ "multi-user.target" ];

        path = with pkgs; [
          # Core
          bash
          coreutils
          curl
          jq
          git
          nix
          nixos-rebuild
          systemd
          util-linux
          gnugrep
          gnused
          gawk
          findutils
          procps
          python3
          which

          # Network tools
          iproute2
          dnsutils
          host
          iputils

          # System monitoring
          sysstat

          # Tailscale
          tailscale

          # NixOS
          nix

          # Desktop applications
          firefox
          gnome-terminal
          nautilus
          zed-editor

          # Desktop control
          wmctrl
          grim
          brightnessctl
          libnotify
          wireplumber
          xset

          # Clipboard
          wl-clipboard

          # Session management
          systemd
        ];

        environment = {
          HOST_NAME = config.networking.hostName;
          REPO_DIR = "/home/ivali/nixos-infrastructure";
          GITLAB_URL = botCfg.gitlabUrl;
          DEFAULT_USER = botCfg.defaultUser;
        };

        serviceConfig = {
          Type = "simple";
          User = "root";
          Group = "root";
          ExecStart = botScript;
          Restart = "on-failure";
          RestartSec = "10s";
          TimeoutStopSec = "30s";
          StandardOutput = "journal";
          StandardError = "journal";
          SyslogIdentifier = "ivali-bot";

          StateDirectory = "ivali-bot";

          NoNewPrivileges = true;
          PrivateTmp = true;
        };
      };

    })

    ##########################################################################
    ## CI Notification — still gated on fleet.gitlabRunner.enable
    ##########################################################################

    (lib.mkIf runnerCfg.enable {

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

    })

  ];
}
