##############################################################################
#
# Security Scanning
#
# Purpose
# -------
# Provides a scheduled security scanner that audits NixOS configuration,
# systemd services, AppArmor, fail2ban, Tailscale, and open ports, then
# exposes results as Prometheus metrics.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Run a comprehensive security scan script (config, services, ports, etc.)
# - Output Prometheus-compatible metrics (scan status, failed units, etc.)
# - Expose metrics via a dedicated HTTP endpoint for Prometheus scraping
# - Schedule scans via systemd timer (default: daily)
# - Enforce hardening on the scan service itself
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.security.scanning;

  # Security scan script that outputs Prometheus metrics
  securityScanScript = pkgs.writeShellScript "security-scan" ''
    #!/bin/sh
    set -euo pipefail

    HOST="${config.networking.hostName}"
    METRICS_FILE="/tmp/security-scan-metrics.prom"
    TIMESTAMP=$(date +%s)

    echo "=== Security Scan Report ==="
    echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Host: $HOST"
    echo ""

    # Initialize metrics
    SCAN_STATUS=1
    FAILED_UNITS=0
    FLAKE_INPUTS=0

    # 1. NixOS configuration check
    echo "--- NixOS Configuration ---"
    FLAKE_INPUTS=$(nix flake metadata --json 2>/dev/null | ${pkgs.jq}/bin/jq '.locks.nodes | length' 2>/dev/null || echo '0')
    echo "Flake inputs: $FLAKE_INPUTS"
    echo ""

    # 2. Store integrity
    echo "--- Store Integrity ---"
    echo "Store size: $(du -sh /nix/store 2>/dev/null | cut -f1 || echo 'unknown')"
    echo "Derivations: $(ls -d /nix/store/*.drv 2>/dev/null | wc -l || echo 0)"
    echo ""

    # 3. Systemd service status
    echo "--- Critical Services ---"
    for svc in tailscaled sops-nix nixos-rebuild-switch; do
      if systemctl is-active --quiet "$svc" 2>/dev/null; then
        echo "$svc: running"
      else
        echo "$svc: stopped"
      fi
    done
    echo ""

    # 4. Failed systemd units
    echo "--- Failed Units ---"
    FAILED_UNITS=$(systemctl list-units --failed --no-legend --no-pager 2>/dev/null | wc -l)
    echo "Failed units: $FAILED_UNITS"
    if [ "$FAILED_UNITS" -gt 0 ]; then
      systemctl list-units --failed --no-legend --no-pager 2>/dev/null
    fi
    echo ""

    # 5. Open ports
    echo "--- Open Ports ---"
    ss -tlnp 2>/dev/null | grep LISTEN | awk '{print $4}' | sort -u || echo "unknown"
    echo ""

    # 6. Security updates
    echo "--- Security Status ---"
    echo "NixOS generation: $(nix-env --list-generations --profile /nix/var/nix/profiles/system 2>/dev/null | tail -1 | awk '{print $1}' || echo 'unknown')"
    echo "Kernel: $(uname -r)"
    echo ""

    # 7. AppArmor status
    echo "--- AppArmor Status ---"
    if command -v aa-status >/dev/null 2>&1; then
      echo "AppArmor: $(aa-status 2>/dev/null | head -1 || echo 'unknown')"
    else
      echo "AppArmor: not installed"
    fi
    echo ""

    # 8. fail2ban status
    echo "--- Fail2Ban Status ---"
    if systemctl is-active --quiet fail2ban 2>/dev/null; then
      echo "Fail2Ban: running"
      fail2ban-client status 2>/dev/null || true
    else
      echo "Fail2Ban: stopped"
    fi
    echo ""

    # 9. Tailscale status
    echo "--- Tailscale Status ---"
    if command -v tailscale >/dev/null 2>&1; then
      TS_IP=$(tailscale ip -4 2>/dev/null || echo "unknown")
      echo "Tailscale IP: $TS_IP"
    else
      echo "Tailscale: not installed"
    fi
    echo ""

    echo "=== Scan Complete ==="

    # Determine overall scan status
    if [ "$FAILED_UNITS" -gt 0 ]; then
      SCAN_STATUS=0
    fi

    # Write Prometheus metrics
    mkdir -p /var/lib/security-scanner
    cat > "$METRICS_FILE" <<EOF
    # HELP security_scan_status Security scan status (1=pass, 0=fail)
    # TYPE security_scan_status gauge
    security_scan_status{host="$HOST"} $SCAN_STATUS

    # HELP security_scan_timestamp Unix timestamp of last security scan
    # TYPE security_scan_timestamp gauge
    security_scan_timestamp{host="$HOST"} $TIMESTAMP

    # HELP security_scan_failed_units Number of failed systemd units
    # TYPE security_scan_failed_units gauge
    security_scan_failed_units{host="$HOST"} $FAILED_UNITS

    # HELP security_scan_flake_inputs Number of flake inputs
    # TYPE security_scan_flake_inputs gauge
    security_scan_flake_inputs{host="$HOST"} $FLAKE_INPUTS
    EOF

    # Exit with failure status if scan found issues
    if [ "$SCAN_STATUS" -eq 0 ]; then
      exit 1
    fi
  '';

in
{
  options.ivali.security.scanning = {
    enable = lib.mkEnableOption "Security scanning";

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "Scan schedule (systemd OnCalendar format)";
    };

    metricsPort = lib.mkOption {
      type = lib.types.port;
      default = 9120;
      description = "Port for the security scanner metrics endpoint";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.security-scan = {
      description = "Security Scan";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = securityScanScript;
        TimeoutStartSec = "300s";
        Nice = 10;
        IOSchedulingClass = "idle";

        # Hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadOnlyPaths = [ "/nix/store" "/proc" "/sys" ];
      };

      path = with pkgs; [
        bash
        coreutils
        curl
        gnugrep
        gnused
        gawk
        dnsutils
        procps
        systemd
        util-linux
        git
        nix
        findutils
        jq
      ];
    };

    systemd.timers.security-scan = {
      description = "Run Security Scan";
      wantedBy = [ "timers.target" ];

      timerConfig = {
        Unit = "security-scan.service";
        OnCalendar = cfg.schedule;
        Persistent = true;
      };
    };

    # Security scanner metrics endpoint
    systemd.services.security-scanner-metrics = {
      description = "Security Scanner Metrics Endpoint";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.bash}/bin/bash -c 'while true; do echo \"HTTP/1.1 200 OK\"; echo \"Content-Type: text/plain\"; echo \"\"; cat /var/lib/security-scanner/security-scan-metrics.prom 2>/dev/null || echo \"# No metrics available\"; sleep 10; done' | ${pkgs.coreutils}/bin/tee /dev/null";
        Restart = "always";
        RestartSec = 10;
      };
    };

    # Expose metrics port
    networking.firewall.allowedTCPPorts = [ cfg.metricsPort ];

    # Add to Prometheus scrape targets
    services.prometheus.scrapeConfigs = [
      {
        job_name = "security-scanner";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString cfg.metricsPort}" ];
            labels = {
              host = config.networking.hostName;
            };
          }
        ];
        scrape_interval = "30s";
      }
    ];
  };
}
