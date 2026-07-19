##############################################################################
#
# Bot Watchdog — dead-man's-switch
#
# Purpose
# -------
# The Telegram bot IS the control plane. If it dies silently you lose
# all remote control. The bot writes /run/ivali-bot/heartbeat on every
# poll (see #8). This timer alerts via notify.sh if the heartbeat goes
# stale.
#
# Ownership
# ---------
# fleet.bot.watchdog.*, systemd ivali-bot-watchdog.{service,timer}
#
# Dependencies
# ------------
# Requires the bot to write the heartbeat file (implemented in #8).
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.fleet.bot.watchdog;

  watchdog = pkgs.writeShellScript "ivali-bot-watchdog" ''
    #!/bin/sh
    set -eu

    HB=/run/ivali-bot/heartbeat
    TH="$1"
    NOTIFY=/home/ivali/nixos-infrastructure/scripts/notify.sh

    if [ ! -e "$HB" ]; then
      if [ -x "$NOTIFY" ]; then
        "$NOTIFY" "⚠️ ivali-bot has no heartbeat file (not running?)"
      fi
      exit 0
    fi

    age="$(( $(date +%s) - $(stat -c %Y "$HB") ))"
    if [ "$age" -gt "$TH" ]; then
      if [ -x "$NOTIFY" ]; then
        "$NOTIFY" "⚠️ ivali-bot unreachable (no poll in ''${age}s)"
      fi
    fi
  '';
in
{
  options.fleet.bot.watchdog = {
    enable = lib.mkEnableOption "bot dead-man's-switch";

    thresholdSec = lib.mkOption {
      type = lib.types.int;
      default = 300;
      description = "Seconds without a heartbeat before alerting.";
    };

    checkInterval = lib.mkOption {
      type = lib.types.int;
      default = 120;
      description = "Seconds between heartbeat checks.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure the bot has a place to write its heartbeat.
    systemd.tmpfiles.settings."d /run/ivali-bot 0755 root root" = "";

    systemd.services.ivali-bot-watchdog = {
      description = "Check ivali-bot heartbeat";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${watchdog} ${builtins.toString cfg.thresholdSec}";
      };
    };

    systemd.timers.ivali-bot-watchdog = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnUnitActiveSec = "${builtins.toString cfg.checkInterval}s";
        Persistent = true;
      };
    };
  };
}
