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
# Desktop commands use call-time session bridging (lib/desktop.sh) to
# discover DBUS_SESSION_BUS_ADDRESS, XDG_RUNTIME_DIR, and WAYLAND_DISPLAY
# from the running desktop session at dispatch time. This avoids baking stale
# env vars at service start and works across session restarts.
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

      after = [
        "network-online.target"
        "graphical.target"
      ];
      wants = [ "network-online.target" ];
      partOf = [ "graphical.target" ];

      wantedBy = [ "graphical.target" ];

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

        # Privilege escalation
        sudo

        # Desktop applications
        firefox
        gnome-terminal
        nautilus
        gnome-console
        zed-editor

        # Desktop control (GNOME)
        brightnessctl
        libnotify
        wireplumber
        glib
        gnome-screenshot
        gnome-shell
        gnome-session

        # Clipboard (Wayland-native)
        wl-clipboard

        # URL/file opening
        xdg-utils
        xdotool

        # Python (for urlencode and scripting)
        python3

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

        # Session env is discovered at call-time by lib/desktop.sh
        # No DISPLAY/WAYLAND_DISPLAY/DBUS_SESSION_BUS_ADDRESS needed here.

        StateDirectory = "ivali-bot";

        # sudo -u user is required for user-context operations
        # (launch_app, clipboard, volume, D-Bus calls).
        PrivateTmp = true;
      };
    };

  };
}
