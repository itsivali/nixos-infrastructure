{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.security.scanning;

  # Security scan script
  securityScanScript = pkgs.writeShellScript "security-scan" ''
    #!/bin/sh
    set -euo pipefail

    echo "=== Security Scan Report ==="
    echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Host: ${config.networking.hostName}"
    echo ""

    # 1. NixOS configuration check
    echo "--- NixOS Configuration ---"
    echo "Flake inputs: $(nix flake metadata --json 2>/dev/null | ${pkgs.jq}/bin/jq '.locks.nodes | length' 2>/dev/null || echo 'unknown')"
    echo ""

    # 2. Store integrity
    echo "--- Store Integrity ---"
    echo "Store size: $(du -sh /nix/store 2>/dev/null | cut -f1 || echo 'unknown')"
    echo "Derivations: $(find /nix/store -maxdepth 1 -name '*.drv' 2>/dev/null | wc -l || echo 0)"
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
    FAILED=$(systemctl list-units --failed --no-legend --no-pager 2>/dev/null | wc -l)
    echo "Failed units: $FAILED"
    if [ "$FAILED" -gt 0 ]; then
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

    echo "=== Scan Complete ==="
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
  };
}
