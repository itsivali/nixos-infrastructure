##############################################################################
#
# Operations Web UI
#
# Purpose
# -------
# Internal operations API server for NixOS infrastructure management.
# Provides REST API endpoints for health, deployments, services, drift
# detection, and audit logging. Designed to be accessed via Tailscale Serve.
#
# Ownership
# ---------
# services/web-ui
#
# Responsibilities
# ----------------
# - Run the operations API server (ivali api)
# - Expose via Tailscale Serve (optional)
# - Provide health check endpoint for monitoring
# - Manage systemd service lifecycle
#
# Usage
# -----
# ivali.services.webUI = {
#   enable = true;
#   port = 8080;
#   tailscaleServe = true;
# };
#
##############################################################################

{ config, lib, pkgs, ... }:

{
  options.ivali.services.webUI = {
    enable = lib.mkEnableOption "Operations Web UI API server";

    port = lib.mkOption {
      type = lib.types.int;
      default = 8080;
      description = ''
        Port for the operations API server.
        This is the local port the server listens on.
      '';
    };

    address = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        Address to bind the operations API server.
        Use 127.0.0.1 for local-only access (recommended with Tailscale Serve).
        Use 0.0.0.0 to listen on all interfaces (only if firewall is configured).
      '';
    };

    repoPath = lib.mkOption {
      type = lib.types.str;
      default = "/home/ivali/nixos-infrastructure";
      description = ''
        Path to the NixOS infrastructure repository.
        Used by the API server for Git operations and deployment.
      '';
    };

    tailscaleServe = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to expose via Tailscale Serve.
        When enabled, the API is accessible at:
        https://{hostname}.{tailnet}/
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to open the API port in the firewall.
        Only enable this if you need direct access without Tailscale.
      '';
    };
  };

  config =
    let
      cfg = config.ivali.services.webUI;
    in
    lib.mkIf cfg.enable {
      # Validate configuration
      assertions = [
        {
          assertion = cfg.port > 0 && cfg.port < 65536;
          message = "Port must be between 1 and 65535";
        }
        {
          assertion = cfg.tailscaleServe -> (config.services.tailscale.enable or false);
          message = "Tailscale Serve requires Tailscale to be enabled";
        }
      ];

      # API authentication token (required for production)
      sops.secrets.api_token = {
        sopsFile = ../../secrets/web-ui.yaml;
        owner = "ivali";
        mode = "0400";
      };

      systemd.services.operations-web-ui = {
        description = "Operations Web UI API Server";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];

        path = with pkgs; [
          bash
          coreutils
          git
          nix
          nixos-rebuild
          systemd
          curl
          procps
        ];

        environment = {
          HOST_NAME = config.networking.hostName;
          REPO_DIR = cfg.repoPath;
          API_ADDR = "${cfg.address}:${toString cfg.port}";
          IVALI_API_TOKEN_FILE = config.sops.secrets.api_token.path;
        };

        preStart = ''
          # Validate required tools exist
          for cmd in git nix nixos-rebuild systemctl; do
            if ! command -v "$cmd" >/dev/null 2>&1; then
              echo "[operations-web-ui] WARNING: Required command '$cmd' not found in PATH"
            fi
          done

          # Validate repository path exists
          if [ ! -d "${cfg.repoPath}" ]; then
            echo "[operations-web-ui] ERROR: Repository path does not exist: ${cfg.repoPath}"
            exit 1
          fi

          echo "[operations-web-ui] Starting operations API on ${cfg.address}:${toString cfg.port}"
          echo "[operations-web-ui] Repository: ${cfg.repoPath}"
          echo "[operations-web-ui] Tailscale Serve: ${if cfg.tailscaleServe then "enabled" else "disabled"}"
        '';

        serviceConfig = {
          Type = "simple";
          User = "ivali";
          ExecStart = "${pkgs.bash}/bin/sh -c '${pkgs.coreutils}/bin/env PATH=/run/current-system/sw/bin ivali api --addr ${cfg.address}:${toString cfg.port}'";
          Restart = "on-failure";
          RestartSec = "5s";

          # Graceful shutdown
          TimeoutStopSec = "30s";
          KillMode = "control-group";
          KillSignal = "SIGTERM";

          # Logging
          SyslogIdentifier = "operations-web-ui";
          StandardOutput = "journal";
          StandardError = "journal";

          # Hardening
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = "read-only";
          ReadWritePaths = [
            "/var/lib/deployment"
            "/var/lib/deployment/audit"
            "/var/lib/observability"
            "/run/deploy.lock"
            "/tmp"
          ] ++ lib.optionals cfg.tailscaleServe [
            "/var/lib/tailscale-metrics"
          ];

          StateDirectory = "deployment";

          # Restrict system calls
          SystemCallFilter = [ "@system-service" "~@privileged" "~@resources" ];
          SystemCallArchitectures = "native";

          # Restrict socket address families to inet (TCP/UDP) and unix (systemd/D-Bus)
          RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
        };

        # Health check for systemd
        unitConfig = {
          StartLimitIntervalSec = "5min";
          StartLimitBurst = 5;
        };
      };

      # Configure Tailscale Serve for the Web UI
      ivali.tailscale.serve = lib.mkIf cfg.tailscaleServe {
        enable = true;
        services = {
          "web-ui" = {
            path = "/";
            target = "http://127.0.0.1:${toString cfg.port}";
            port = 443;
            healthCheck = "/api/health";
            after = [ "operations-web-ui.service" ];
          };
        };
      };

      # Open firewall port if requested
      networking.firewall = lib.mkIf (cfg.openFirewall && !cfg.tailscaleServe) {
        allowedTCPPorts = [ cfg.port ];
      };
    };
}
