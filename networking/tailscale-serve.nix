##############################################################################
#
# Tailscale Serve
#
# Purpose
# -------
# Expose local services securely over Tailscale tailnet using Tailscale Serve
# or Tailscale Funnel. Provides HTTPS access without opening firewall ports.
#
# Ownership
# ---------
# networking/tailscale-serve.nix
#
# Responsibilities
# ----------------
# - Configure Tailscale Serve/Funnel for local services
# - Create systemd services for each served endpoint
# - Manage Tailscale Serve lifecycle (setup/teardown)
# - Provide health check endpoints for served services
#
# Usage
# -----
# ivali.tailscale.serve = {
#   enable = true;
#   services."web-ui" = {
#     path = "/";
#     target = "http://127.0.0.1:8080";
#     healthCheck = "/api/health";
#   };
# };
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.tailscale.serve;

  # Helper to create a Tailscale Serve systemd service
  mkTailscaleServeService = name: serviceCfg:
    let
      # Build the tailscale serve command arguments
      serveArgs = lib.concatStringsSep " " ([
        "--bg"
        "--https=${toString serviceCfg.port}"
      ] ++ lib.optionals serviceCfg.http [
        "--http=${toString serviceCfg.httpPort}"
      ] ++ lib.optionals serviceCfg.funnel [
        "--funnel"
      ]);

      # Build the full URL for the target
      targetUrl = serviceCfg.target;

      # Health check URL for readiness probe
      healthUrl =
        if serviceCfg.healthCheck != null then
          "${targetUrl}${serviceCfg.healthCheck}"
        else
          null;

    in
    {
      "tailscale-serve-${name}" = {
        description = "Tailscale Serve for ${name}";
        after = [ "tailscaled.service" ] ++ serviceCfg.after;
        wants = [ "tailscaled.service" ];
        wantedBy = lib.optionals serviceCfg.autoStart [ "multi-user.target" ];

        path = [
          pkgs.tailscale
          pkgs.coreutils
          pkgs.curl
          pkgs.bash
        ];

        environment = {
          TS_SERVE_PATH = serviceCfg.path;
          TS_SERVE_TARGET = targetUrl;
          TS_SERVE_NAME = name;
        };

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };

        preStart = ''
          # Wait for tailscaled to be ready (max 30s)
          echo "[tailscale-serve-${name}] Waiting for tailscaled..."
          for i in $(seq 1 30); do
            if tailscale status >/dev/null 2>&1; then
              echo "[tailscale-serve-${name}] tailscaled is ready"
              break
            fi
            if [ "$i" -eq 30 ]; then
              echo "[tailscale-serve-${name}] ERROR: tailscaled not ready after 30s"
              exit 1
            fi
            sleep 1
          done

          # Wait for target service to be healthy (if health check configured)
          ${lib.optionalString (healthUrl != null) ''
            echo "[tailscale-serve-${name}] Waiting for health check at ${healthUrl}..."
            for i in $(seq 1 60); do
              if curl -sf "${healthUrl}" >/dev/null 2>&1; then
                echo "[tailscale-serve-${name}] Health check passed"
                break
              fi
              if [ "$i" -eq 60 ]; then
                echo "[tailscale-serve-${name}] WARNING: Health check not ready after 60s, proceeding anyway"
              fi
              sleep 1
            done
          ''}
        '';

        script = ''
          # Remove existing serve config for this path (idempotent)
          echo "[tailscale-serve-${name}] Removing existing serve config for ${serviceCfg.path}..."
          tailscale serve --bg --remove ${serviceCfg.path} 2>/dev/null || true

          # Configure Tailscale Serve
          echo "[tailscale-serve-${name}] Configuring serve: ${serviceCfg.path} -> ${targetUrl}"
          tailscale serve ${serveArgs} ${serviceCfg.path} ${targetUrl}

          echo "[tailscale-serve-${name}] Tailscale Serve configured successfully"
        '';

        preStop = ''
          echo "[tailscale-serve-${name}] Removing serve config for ${serviceCfg.path}..."
          tailscale serve --bg --remove ${serviceCfg.path} 2>/dev/null || true
          echo "[tailscale-serve-${name}] Serve config removed"
        '';
      };
    };

in
{
  options.ivali.tailscale.serve = {
    enable = lib.mkEnableOption "Tailscale Serve for local services";

    services = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          path = lib.mkOption {
            type = lib.types.str;
            example = "/api/health";
            description = ''
              The path to serve via Tailscale.
              This is the external path that will be accessible via the tailnet.
            '';
          };

          target = lib.mkOption {
            type = lib.types.str;
            example = "http://127.0.0.1:8080";
            description = ''
              The local target to proxy to.
              Must be a valid HTTP/HTTPS URL.
            '';
          };

          port = lib.mkOption {
            type = lib.types.int;
            default = 443;
            description = ''
              The HTTPS port to use for Tailscale Serve.
              Default is 443 for standard HTTPS.
            '';
          };

          http = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Also serve over HTTP (in addition to HTTPS).
              HTTP will be available on port 80.
            '';
          };

          httpPort = lib.mkOption {
            type = lib.types.int;
            default = 80;
            description = ''
              The HTTP port to use when http = true.
            '';
          };

          funnel = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Use Tailscale Funnel to expose this service to the public internet.
              WARNING: This makes the service accessible outside your tailnet.
            '';
          };

          healthCheck = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "/api/health";
            description = ''
              Optional health check endpoint path.
              If set, the service will wait for this endpoint to respond
              before configuring Tailscale Serve.
            '';
          };

          after = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = ''
              Additional systemd services to depend on.
              The tailscaled.service is always included.
            '';
          };

          autoStart = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Whether to start this serve configuration automatically.
              If false, you must manually start tailscale-serve-{name}.
            '';
          };
        };
      });
      default = { };
      description = "Services to expose via Tailscale Serve";
    };
  };

  config = lib.mkIf cfg.enable {
    # Validate Tailscale is enabled
    assertions = [
      {
        assertion = config.services.tailscale.enable or false;
        message = "Tailscale Serve requires Tailscale to be enabled (services.tailscale.enable = true)";
      }
    ];

    # Create systemd services for each Tailscale Serve endpoint
    systemd.services = lib.concatMapAttrs mkTailscaleServeService cfg.services;
  };
}
