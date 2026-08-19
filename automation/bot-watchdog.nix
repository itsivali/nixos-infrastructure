##############################################################################
#
# Bot Watchdog — dead-man's-switch
#
# Purpose
# -------
# The Telegram bot IS the control plane. If it dies silently you lose
# all remote control. The bot writes /run/ivali-bot/heartbeat.json on
# every 30-minute heartbeat. This timer alerts via notify.sh if the
# heartbeat goes stale or health metrics are degraded.
#
# Ownership
# ---------
# fleet.bot.watchdog.*, systemd ivali-bot-watchdog.{service,timer}
#
# Dependencies
# ------------
# Requires the bot to write JSON heartbeat files.
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.fleet.bot.watchdog;

  notifyScript = import ../shared/notify.nix { inherit pkgs; };

  watchdog = pkgs.writeShellScript "ivali-bot-watchdog" ''
    #!/bin/sh
    set -eu

    HB=/run/ivali-bot/heartbeat.json
    STATE=/var/lib/bot-watchdog/notified
    THRESHOLD=$1  # seconds without heartbeat before alerting

    NOTIFY="''${NOTIFY:-$(command -v notify 2>/dev/null || echo /run/current-system/sw/bin/notify)}"

    # Skip if bot service not running (fresh boot — not yet started)
    if ! systemctl is-active --quiet ivali-bot-go.service 2>/dev/null; then
      rm -f "$STATE"
      exit 0
    fi

    # 1. Check heartbeat file exists
    if [ ! -e "$HB" ]; then
      if [ ! -f "$STATE" ] || [ "$(($(date +%s) - $(stat -c %Y "$STATE")))" -gt 3600 ]; then
        if [ -x "$NOTIFY" ]; then
          "$NOTIFY" "⚠️ ivali-bot has no heartbeat file on $(hostname) (not running?)"
        fi
        mkdir -p "$(dirname "$STATE")"
        date -Iseconds > "$STATE"
      fi
      exit 0
    fi

    # 2. Check heartbeat age
    if ! command -v jq >/dev/null 2>&1; then
      echo "jq not available — skipping watchdog" >&2
      exit 0
    fi

    TIMESTAMP=$(jq -r '.timestamp // empty' "$HB" 2>/dev/null || echo "")
    if [ -z "$TIMESTAMP" ]; then
      echo "Invalid heartbeat JSON" >&2
      exit 0
    fi

    AGE=$(( $(date +%s) - $(date -d "$TIMESTAMP" +%s 2>/dev/null || echo 0) ))

    if [ "$AGE" -gt "$THRESHOLD" ]; then
      if [ ! -f "$STATE" ] || [ "$(($(date +%s) - $(stat -c %Y "$STATE")))" -gt 3600 ]; then
        LOAD=$(jq -r '.system.load[0] // "?"' "$HB" 2>/dev/null || echo "?")
        MEM=$(jq -r '.system.memory_pct // "?"' "$HB" 2>/dev/null || echo "?")
        DISK=$(jq -r '.system.disk_pct // "?"' "$HB" 2>/dev/null || echo "?")
        ERRS=$(jq -r '.totals.errors_total // 0' "$HB" 2>/dev/null || echo "0")
        if [ -x "$NOTIFY" ]; then
          "$NOTIFY" "⚠️ ivali-bot unreachable on $(hostname) (last: ''${AGE}s ago, load: ''${LOAD}, mem: ''${MEM}%, disk: ''${DISK}%, errors: ''${ERRS})"
        fi
        mkdir -p "$(dirname "$STATE")"
        date -Iseconds > "$STATE"
      fi
      exit 0
    fi

    # 3. Health checks — bot is alive, check metrics
    MEM=$(jq -r '.system.memory_pct // 0' "$HB" 2>/dev/null || echo "0")
    DISK=$(jq -r '.system.disk_pct // 0' "$HB" 2>/dev/null || echo "0")
    LOAD=$(jq -r '.system.load[0] // 0' "$HB" 2>/dev/null || echo "0")

    ALERTS=""
    if [ "$MEM" -gt 90 ] 2>/dev/null; then
      ALERTS+="memory ''${MEM}%, "
    fi
    if [ "$DISK" -gt 90 ] 2>/dev/null; then
      ALERTS+="disk ''${DISK}%, "
    fi
    # Bash doesn't support float comparison, truncate to int
    LOAD_INT=$(echo "$LOAD" | cut -d. -f1)
    if [ "''${LOAD_INT:-0}" -gt 4 ] 2>/dev/null; then
      ALERTS+="load ''${LOAD}, "
    fi

    if [ -n "$ALERTS" ]; then
      if [ ! -f "$STATE" ] || [ "$(($(date +%s) - $(stat -c %Y "$STATE")))" -gt 3600 ]; then
        ALERTS="''${ALERTS%, }"
        if [ -x "$NOTIFY" ]; then
          "$NOTIFY" "⚠️ ivali-bot health warning on $(hostname): ''${ALERTS}"
        fi
        mkdir -p "$(dirname "$STATE")"
        date -Iseconds > "$STATE"
      fi
    else
      # All clear — remove cooldown state so next alert can fire
      rm -f "$STATE"
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
    systemd.tmpfiles.settings."d /run/ivali-bot 0755 root root" = { };
    systemd.tmpfiles.settings."d /var/lib/bot-watchdog 0755 root root" = { };

    systemd.services.ivali-bot-watchdog = {
      description = "Check ivali-bot heartbeat";
      serviceConfig = {
        Type = "oneshot";
        path = [
          notifyScript
          pkgs.coreutils
          pkgs.jq
          pkgs.systemd
        ];
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
