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

{ config, lib, pkgs, self, ... }:

let
  cfg = config.fleet.bot;

  system = pkgs.stdenv.hostPlatform.system;

  # Reference the canonical packages defined in flake.nix — avoids
  # duplicating vendorHash here (single source of truth in flake.nix).
  botPackage = self.packages.${system}.ivali-bot;
  ivaliCli = self.packages.${system}.ivali;
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
        grim # screenshots (Wayland)
        wl-clipboard # wl-copy / wl-paste
        libnotify # notify-send
        wmctrl
        glib # gdbus
        xset # xset
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

        # Guarantee the watchdog heartbeat directory exists independent of the
        # watchdog's own tmpfiles entry.
        RuntimeDirectory = "ivali-bot";

        # Security hardening
        NoNewPrivileges = false;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        ReadWritePaths = [
          "/var/lib/ivali-bot"
          "/var/log"
          "/run"
          "/run/secrets"
          "/nix"
          "/etc/nixos"
          # The flake repository: deploy/git pull/ivali reconcile must write
          # the checkout, so it is exempted from ProtectHome=read-only.
          "/home/ivali/nixos-infrastructure"
        ];
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
      };
    };

  };
}
