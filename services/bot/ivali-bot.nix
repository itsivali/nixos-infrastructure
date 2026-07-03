##############################################################################
#
# Telegram Bot Service
#
# Purpose
# -------
# Telegram bot control plane for remote infrastructure management.
#
# Ownership
# ---------
# systemd.services.ivali-bot
#
# Dependencies
# ------------
# Requires fleet.bot options (declared in automation/options.nix).
#
##############################################################################

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
in
{
  config = lib.mkIf botCfg.enable {

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
        gnome-screenshot
        brightnessctl
        libnotify
        wireplumber
        glib          # provides gdbus for GNOME Shell DBus calls

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

  };
}
