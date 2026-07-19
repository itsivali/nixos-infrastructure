##############################################################################
#
# Go Telegram Bot Service
#
# Purpose
# -------
# Go-based Telegram bot for NixOS infrastructure management.
# This is the new Go implementation replacing the shell-based bot.
#
# Ownership
# ---------
# systemd.services.ivali-bot-go
#
# Dependencies
# ------------
# Requires fleet.bot options (declared in automation/options.nix).
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.fleet.bot;

  botPackage = pkgs.buildGoModule {
    name = "ivali-bot";
    src = pkgs.lib.cleanSource ./../../.;
    vendorHash = "sha256-26Sj0Wx3u1tfgxjJey3fpa/wGqh+7/MCVEGJZgWzbzU=";
    subPackages = [ "cmd/ivali-bot" ];
  };

  # The bot runs shell commands via `sh -c` (helpers.go runCmd) and the
  # /doctor command invokes `ivali doctor`, so both `sh` and the ivali CLI
  # must be on its restricted PATH.
  ivaliCli = pkgs.buildGoModule {
    name = "ivali";
    src = pkgs.lib.cleanSource ./../../.;
    vendorHash = "sha256-26Sj0Wx3u1tfgxjJey3fpa/wGqh+7/MCVEGJZgWzbzU=";
    subPackages = [ "cmd/ivali" ];
    preBuild = "export CGO_ENABLED=0";
  };
in
{
  config = lib.mkIf cfg.enable {

    systemd.services.ivali-bot-go = {
      description = "Telegram Bot (Go)";

      after = [
        "network-online.target"
        "graphical.target"
      ];
      wants = [ "network-online.target" ];
      partOf = [ "graphical.target" ];

      wantedBy = [ "graphical.target" ];

      path = with pkgs; [
        bash
        coreutils
        git
        ivaliCli
        nix
        nixos-rebuild
        systemd
        procps
        sudo

        # Desktop / session automation (run as DEFAULT_USER via sudo)
        gnugrep
        findutils
        curl
        jq
        glibc.bin # getent (system users)
        nftables # nft (security)
        apparmor-utils # aa-status (security)
        wireplumber # wpctl (volume/mute)
        brightnessctl
        gnome-screenshot
        wl-clipboard # wl-copy / wl-paste
        libnotify # notify-send
        wmctrl
        glib # gdbus
        xorg.xset # xset
        firefox
      ];

      environment = {
        HOST_NAME = config.networking.hostName;
        REPO_DIR = "/home/ivali/nixos-infrastructure";
        GITLAB_URL = cfg.gitlabUrl;
        DEFAULT_USER = cfg.defaultUser;
      };

      serviceConfig = {
        Type = "simple";
        User = "root";
        Group = "root";
        ExecStart = "${botPackage}/bin/ivali-bot";
        Restart = "on-failure";
        RestartSec = "10s";
        TimeoutStopSec = "30s";
        StandardOutput = "journal";
        # Confine via AppArmor (profile installed by security/apparmor.nix)
        AppArmorProfile = "ivali-bot";
        StandardError = "journal";
        SyslogIdentifier = "ivali-bot-go";

        StateDirectory = "ivali-bot";

        # Security hardening
        NoNewPrivileges = false;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        ReadWritePaths = [
          "/var/lib/ivali-bot"
          "/var/log"
          "/run/secrets"
          "/etc/nixos"
        ];
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
      };
    };

  };
}
