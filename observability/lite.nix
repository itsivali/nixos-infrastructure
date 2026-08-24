##############################################################################
#
# Observability (Lite) — low-CPU health collector
#
# Purpose
# -------
# The full stack (Prometheus/Grafana/Alloy/Falco) is too heavy for
# this laptop's CPU. This is the cheap substitute: a 60s timer that
# reads /proc, writes /var/lib/observability/state.json, and fires
# notify.sh when a threshold is breached. Health status is exposed via
# the operations WebUI dashboard.
# reads the same state file.
#
# Ownership
# ---------
# fleet.observability.lite.*, systemd observability-lite.{service,timer}
#
# Dependencies
# ------------
# Uses notify.sh for alerts (non-fatal, same as reconciler).
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.fleet.observability.lite;

  notifyScript = import ../shared/notify.nix { inherit pkgs; };

  collector = pkgs.writeShellScript "observability-lite" ''
    #!/bin/sh
    set -eu

    OUT=/var/lib/observability/state.json
    NOTIFY="''${NOTIFY:-$(command -v notify 2>/dev/null || echo /run/current-system/sw/bin/notify)}"

    GEN="$(readlink -f /run/current-system | sed 's#.*/\([0-9]*\)-link#\1#')"
    HOST="$(hostname)"
    ts="$(date +%s)"
    up="$(awk '{print $1}' /proc/uptime)"
    read -r l1 l5 l15 _ < /proc/loadavg

    memT="$(awk '/MemTotal/{print $2}' /proc/meminfo)"
    memA="$(awk '/MemAvailable/{print $2}' /proc/meminfo)"
    memPct="$(( (memT - memA) * 100 / memT ))"
    nproc="$(nproc)"
    diskRoot="$(df -P / | awk 'NR==2{gsub("%","",$5); print $5}')"

    svc_net="$(systemctl is-active network-online.target 2>/dev/null || echo unknown)"

    diskTh=${toString cfg.thresholds.disk}
    memTh=${toString cfg.thresholds.mem}
    loadTh="$(awk "BEGIN{printf \"%.1f\", ''${nproc} * ${toString cfg.thresholds.load}}")"

    alerts=""
    if [ "$diskRoot" -ge "$diskTh" ]; then alerts="''${alerts}disk_root=''${diskRoot}% "; fi
    if [ "$memPct" -ge "$memTh" ]; then alerts=" ''${alerts}mem=''${memPct}% "; fi
    if awk "BEGIN{exit !($l1 > $loadTh)}"; then alerts="''${alerts}load1=''${l1} "; fi

    cat > "$OUT" <<JSON
    {"host":"$HOST","gen":"$GEN","ts":$ts,"uptime":$up,"load":[$l1,$l5,$l15],"memPct":$memPct,"diskRootPct":$diskRoot,"net":"$svc_net","alerts":"$alerts"}
    JSON

    if [ -n "$alerts" ] && [ -x "$NOTIFY" ]; then
      "$NOTIFY" "⚠️ ''${HOST} health alert: ''${alerts}"
    fi
  '';
in
{
  options.fleet.observability.lite = {
    enable = lib.mkEnableOption "lite /proc-based health collector";

    interval = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = "Seconds between metric collections.";
    };

    thresholds = {
      disk = lib.mkOption {
        type = lib.types.int;
        default = 85;
        description = "Root filesystem used%% that triggers an alert.";
      };
      mem = lib.mkOption {
        type = lib.types.int;
        default = 90;
        description = "Memory used%% that triggers an alert.";
      };
      load = lib.mkOption {
        type = lib.types.float;
        default = 2.0;
        description = "load1 multiplier over (nproc) that triggers an alert.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.gawk pkgs.procps ];

    systemd.services.observability-lite = {
      description = "Lite observability collector";
      serviceConfig = {
        Type = "oneshot";
        Nice = 19;
        IOSchedulingClass = "idle";
        StateDirectory = "observability";
        path = [
          notifyScript
          pkgs.coreutils
          pkgs.curl
          pkgs.gawk
          pkgs.procps
        ];
        ExecStart = "${collector}";
      };
    };

    systemd.timers.observability-lite = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnUnitActiveSec = "${toString cfg.interval}s";
        Persistent = true;
      };
    };
  };
}
