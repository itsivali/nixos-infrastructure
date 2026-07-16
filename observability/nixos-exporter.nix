{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.observability.exporters;

  # Cache update runs every 15 minutes (heavy operations)
  cacheUpdateScript = pkgs.writeShellScript "nixos-exporter-cache" ''
        CACHE_FILE="/var/cache/nixos-exporter/metrics"
        mkdir -p "$(dirname "$CACHE_FILE")"

        cat > "$CACHE_FILE" << CACHEEOF
    # HELP nixos_store_size_bytes Size of /nix/store in bytes (updated hourly)
    # TYPE nixos_store_size_bytes gauge
    nixos_store_size_bytes $(du -sb /nix/store 2>/dev/null | cut -f1 || echo 0)

    # HELP nixos_flake_inputs Number of flake inputs
    # TYPE nixos_flake_inputs gauge
    nixos_flake_inputs $(nix flake metadata --json 2>/dev/null | ${pkgs.jq}/bin/jq '.locks.nodes | length' 2>/dev/null || echo 0)
    CACHEEOF
  '';

  # Main exporter runs every 5 minutes (lightweight operations only)
  nixosExporterScript = pkgs.writeShellScript "nixos-exporter" ''
        #!/bin/sh
        set -euo pipefail

        PORT="''${NIXOS_EXPORTER_PORT:-9101}"
        CACHE_FILE="/var/cache/nixos-exporter/metrics"
        METRICS_FILE=$(mktemp /tmp/nixos-exporter-XXXXXX)
        trap 'rm -f "$METRICS_FILE"' EXIT

        while true; do
          cat > "$METRICS_FILE" << EOF
    # HELP nixos_generation_current Current NixOS generation number
    # TYPE nixos_generation_current gauge
    nixos_generation_current $(nix-env --list-generations --profile /nix/var/nix/profiles/system 2>/dev/null | tail -1 | awk '{print $1}' || echo 0)

    # HELP nixos_generation_total Total number of NixOS generations
    # TYPE nixos_generation_total gauge
    nixos_generation_total $(nix-env --list-generations --profile /nix/var/nix/profiles/system 2>/dev/null | wc -l || echo 0)

    $(cat "$CACHE_FILE" 2>/dev/null || echo "# cache not ready")

    # HELP nixos_system_uptime_seconds System uptime in seconds
    # TYPE nixos_system_uptime_seconds gauge
    nixos_system_uptime_seconds $(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo 0)

    # HELP nixos_git_dirty Whether the git repo has uncommitted changes (1=yes, 0=no)
    # TYPE nixos_git_dirty gauge
    nixos_git_dirty $(cd /home/ivali/nixos-infrastructure 2>/dev/null && git status --porcelain 2>/dev/null | wc -l | tr -d ' ' || echo 0)

    # HELP nixos_git_behind Number of commits behind remote
    # TYPE nixos_git_behind gauge
    nixos_git_behind $(cd /home/ivali/nixos-infrastructure 2>/dev/null && git rev-list --count HEAD..@{u} 2>/dev/null || echo 0)

    # HELP nixos_deployment_health_last_check_timestamp Timestamp of last successful health check
    # TYPE nixos_deployment_health_last_check_timestamp gauge
    nixos_deployment_health_last_check_timestamp $(stat -c %Y /tmp/deployment-health-last-ok 2>/dev/null || echo 0)

    # HELP nixos_deployment_health_status Last health check status (1=ok, 0=fail)
    # TYPE nixos_deployment_health_status gauge
    nixos_deployment_health_status $([ -f /tmp/deployment-health-last-ok ] && echo 1 || echo 0)
    EOF

          echo "HTTP/1.1 200 OK"
          echo "Content-Type: text/plain; version=0.0.4"
          echo ""
          cat "$METRICS_FILE"
          sleep 300
        done
  '';

in
{
  options.ivali.observability.exporters = {
    enable = lib.mkEnableOption "NixOS Prometheus exporter";

    port = lib.mkOption {
      type = lib.types.port;
      default = 9101;
      description = "Port for the NixOS exporter";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.nixos-exporter = {
      description = "NixOS Prometheus Exporter";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.bash}/bin/bash -c '${nixosExporterScript} | ${pkgs.coreutils}/bin/tee /dev/null'";
        Restart = "always";
        RestartSec = 60;
        MemoryMax = "64M";
        CPUQuota = "5%";
        CPUWeight = 20;
      };

      # Hardening
      serviceConfig = {
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadOnlyPaths = [ "/nix/store" "/proc" "/sys" ];
      };
    };

    systemd.services.nixos-exporter-cache = {
      description = "NixOS Prometheus Exporter Cache Update";
      after = [ "network.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = cacheUpdateScript;
        CPUQuota = "10%";
        CPUWeight = 30;
      };
    };

    systemd.timers.nixos-exporter-cache = {
      description = "Update NixOS exporter cache every 15 minutes";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/15";
        Persistent = true;
        RandomizedDelaySec = "60";
      };
    };

    # Expose port in firewall for Prometheus scraping
    networking.firewall.allowedTCPPorts = [ cfg.port ];

    # Add to Prometheus scrape targets
    services.prometheus.scrapeConfigs = [
      {
        job_name = "nixos-exporter";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString cfg.port}" ];
            labels = {
              host = config.networking.hostName;
            };
          }
        ];
        scrape_interval = "300s";
      }
    ];
  };
}
