{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.observability.healthEndpoint;

  # Simple HTTP health endpoint
  healthScript = pkgs.writeShellScript "health-endpoint" ''
    #!/bin/sh
    set -euo pipefail

    PORT="''${HEALTH_PORT:-9100}"

    # Run health check
    HEALTH_OUTPUT=$(${../scripts/deployment-health.sh} 2>&1) || true

    # Count results
    PASS_COUNT=$(echo "$HEALTH_OUTPUT" | grep -c '\[PASS\]' || echo 0)
    WARN_COUNT=$(echo "$HEALTH_OUTPUT" | grep -c '\[WARN\]' || echo 0)
    FAIL_COUNT=$(echo "$HEALTH_OUTPUT" | grep -c '\[FAIL\]' || echo 0)

    # Determine status
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
      "host": "${config.networking.hostName}",
      "checks": {
        "pass": $PASS_COUNT,
        "warn": $WARN_COUNT,
        "fail": $FAIL_COUNT
      },
      "uptime": $(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo 0),
      "generation": $(nix-env --list-generations --profile /nix/var/nix/profiles/system 2>/dev/null | tail -1 | awk '{print $1}' || echo 0),
      "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    }
    EOF
    )

    # Write last check timestamp
    touch /tmp/deployment-health-last-ok 2>/dev/null || true

    # Simple HTTP response
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
  };

  config = lib.mkIf cfg.enable {
    systemd.services.health-endpoint = {
      description = "Health Check HTTP Endpoint";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.bash}/bin/bash -c '${healthScript}'";
        Restart = "always";
        RestartSec = 10;
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
      ];

      # Hardening
      serviceConfig = {
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadOnlyPaths = [ "/nix/store" "/proc" "/sys" ];
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
