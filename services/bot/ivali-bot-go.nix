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

{ config, lib, pkgs, self ? null, ... }:

let
  cfg = config.fleet.bot;

  botPackage =
    if self != null && self.packages ? ${pkgs.system}
    then self.packages.${pkgs.system}.ivali-bot
    else
      pkgs.buildGoModule {
        name = "ivali-bot";
        src = self.outPath or (pkgs.lib.cleanSource ./../../.);
        vendorHash = "sha256-26Sj0Wx3u1tfgxjJey3fpa/wGqh+7/MCVEGJZgWzbzU=";
        subPackages = [ "cmd/ivali-bot" ];
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
        coreutils
        git
        nix
        nixos-rebuild
        systemd
        procps
        sudo
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
