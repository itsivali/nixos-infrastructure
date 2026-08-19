##############################################################################
#
# Health Endpoint
#
# Purpose
# -------
# Lightweight HTTP health endpoint for deployment health checks.
# Optimized for low CPU usage — runs checks every 60 seconds, not 10.
#
# Ownership
# ---------
# systemd.services.health-endpoint
#
# Responsibilities
# ----------------
# - HTTP health check endpoint
# - Deep service health checks
# - Prometheus metrics exposure
# - JSON health response
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.observability.healthEndpoint;
  hostName = config.networking.hostName;

  # Health check script — optimized for low CPU
  healthScript = pkgs.writeShellScript "health-endpoint" ''
    #!/bin/sh
    set -euo pipefail

    PORT="''${HEALTH_PORT:-9100}"
    CACHE_FILE="/var/lib/health-endpoint/cache"
    CACHE_TTL=60

    # Check if cache is fresh
    if [ -f "$CACHE_FILE" ]; then
      CACHE_AGE=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE") ))
      if [ "$CACHE_AGE" -lt "$CACHE_TTL" ]; then
        cat "$CACHE_FILE"
        exit 0
      fi
    fi

    # Initialize counters
    PASS_COUNT=0
    WARN_COUNT=0
    FAIL_COUNT=0
    CHECKS=""

    # Helper function to add check result
    add_check() {
      local name="$1"
      local status="$2"
      local message="$3"

      CHECKS="$CHECKS{\"name\":\"$name\",\"status\":\"$status\",\"message\":\"$message\"},"

      case "$status" in
        pass) PASS_COUNT=$((PASS_COUNT + 1)) ;;
        warn) WARN_COUNT=$((WARN_COUNT + 1)) ;;
        fail) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
      esac
    }

    # 1. NixOS generation check (cached)
    GEN=$(nix-env --list-generations --profile /nix/var/nix/profiles/system 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
    if [ "$GEN" -gt 0 ]; then
      add_check "nixos_generation" "pass" "Generation $GEN"
    else
      add_check "nixos_generation" "warn" "Cannot determine generation"
    fi

    # 2. Systemd services check (lightweight)
    FAILED_UNITS=$(systemctl list-units --failed --no-legend --no-pager 2>/dev/null | wc -l)
    if [ "$FAILED_UNITS" -eq 0 ]; then
      add_check "systemd_services" "pass" "No failed units"
    elif [ "$FAILED_UNITS" -le 2 ]; then
      add_check "systemd_services" "warn" "$FAILED_UNITS failed units"
    else
      add_check "systemd_services" "fail" "$FAILED_UNITS failed units"
    fi

    # 3. Disk space check (cached)
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    if [ "$DISK_USAGE" -lt 80 ]; then
      add_check "disk_space" "pass" "''${DISK_USAGE}% used"
    elif [ "$DISK_USAGE" -lt 90 ]; then
      add_check "disk_space" "warn" "''${DISK_USAGE}% used"
    else
      add_check "disk_space" "fail" "''${DISK_USAGE}% used"
    fi

    # 4. Memory check (lightweight)
    MEM_AVAIL=$(free -m | awk '/^Mem:/ {print $7}')
    MEM_TOTAL=$(free -m | awk '/^Mem:/ {print $2}')
    MEM_PERCENT=$((100 - (MEM_AVAIL * 100 / MEM_TOTAL)))
    if [ "$MEM_PERCENT" -lt 80 ]; then
      add_check "memory" "pass" "''${MEM_PERCENT}% used (''${MEM_AVAIL}MB available)"
    elif [ "$MEM_PERCENT" -lt 90 ]; then
      add_check "memory" "warn" "''${MEM_PERCENT}% used (''${MEM_AVAIL}MB available)"
    else
      add_check "memory" "fail" "''${MEM_PERCENT}% used (''${MEM_AVAIL}MB available)"
    fi

    # 5. Network connectivity check (skip if recently passed)
    if [ -f "$CACHE_FILE" ] && grep -q '"network".*"pass"' "$CACHE_FILE" 2>/dev/null; then
      add_check "network" "pass" "Internet reachable"
    elif ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
      add_check "network" "pass" "Internet reachable"
    else
      add_check "network" "fail" "Internet unreachable"
    fi

    # 6. Tailscale check (lightweight)
    if systemctl is-active --quiet tailscaled 2>/dev/null; then
      add_check "tailscale" "pass" "Running"
    else
      add_check "tailscale" "warn" "Tailscaled not running"
    fi

    # 7. Critical services (lightweight status checks)
    for svc in prometheus grafana; do
      if systemctl is-active --quiet "$svc" 2>/dev/null; then
        add_check "$svc" "pass" "Running"
      else
        add_check "$svc" "warn" "Not running"
      fi
    done

    # Remove trailing comma from checks
    CHECKS="''${CHECKS%,}"

    # Determine overall status
    if [ "$FAIL_COUNT" -gt 0 ]; then
      STATUS="degraded"
      HTTP_CODE="503"
    elif [ "$WARN_COUNT" -gt 0 ]; then
      STATUS="warning"
      HTTP_CODE="200"
    else
      STATUS="healthy"
      HTTP_CODE="200"
    fi

    # Build JSON response
    RESPONSE=$(cat <<EOF
    {
      "status": "$STATUS",
      "host": "${hostName}",
      "checks": {
        "pass": $PASS_COUNT,
        "warn": $WARN_COUNT,
        "fail": $FAIL_COUNT
      },
      "details": [$CHECKS],
      "uptime": $(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo 0),
      "generation": $GEN,
      "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    }
    EOF
    )

    # Cache the response
    mkdir -p /var/lib/health-endpoint
    echo "$RESPONSE" > "$CACHE_FILE"
    date +%s > /var/lib/health-endpoint/last-check

    # HTTP response
    echo "HTTP/1.1 $HTTP_CODE OK"
    echo "Content-Type: application/json"
    echo "Access-Control-Allow-Origin: *"
    echo ""
    echo "$RESPONSE"
  '';

in
{
  options.ivali.observability.healthEndpoint = {
    enable = lib.mkEnableOption "Health endpoint HTTP server";

    port = lib.mkOption {
      type = lib.types.port;
      default = 9100;
      description = "Port for the health endpoint";
    };

    enableDeepChecks = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable deep health checks for all services";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.health-endpoint = {
      description = "Health Check HTTP Endpoint";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        # Serve the health script over HTTP on cfg.port (one fork per connection).
        ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:${toString cfg.port},fork,reuseaddr,bind=127.0.0.1 SYSTEM:'${healthScript}'";
        Restart = "always";
        RestartSec = 5;
        MemoryMax = "8M";
        CPUQuota = "0.25%";
        CPUWeight = 15;

        # Hardening
        StateDirectory = "health-endpoint";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadOnlyPaths = [ "/nix/store" "/proc" "/sys" ];
      };

      # Required for health check script
      path = with pkgs; [
        bash
        coreutils
        curl
        gnugrep
        gnused
        gawk
        dnsutils
        iputils
        procps
        systemd
        util-linux
        git
        nix
        socat
      ];
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
