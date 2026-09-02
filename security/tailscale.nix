##############################################################################
#
# Security Tailscale
#
# Purpose
# -------
# Configures the Tailscale zero-trust networking daemon with optional exit
# node advertising, MagicDNS, Tailscale SSH, key expiry monitoring, and
# Prometheus metrics collection.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Enable and configure Tailscale with auth key, tags, and routing features
# - Manage exit node routing (IP forwarding sysctl)
# - Monitor key expiry via daily systemd timer
# - Export Prometheus metrics (connection status, key expiry, MagicDNS)
# - Validate tag format at build time via assertions
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.tailscale;

  # Build the final tag list: always include the configured tags,
  # and append tag:exit-node automatically when advertising as an exit node.
  effectiveTags =
    cfg.tags
    ++ lib.optional (cfg.advertiseExitNode && !(builtins.elem "tag:exit-node" cfg.tags))
      "tag:exit-node";

  advertisedTags = lib.concatStringsSep "," effectiveTags;

  # Validate tag format: must start with "tag:" and contain only alphanumeric, hyphens, underscores
  validateTag = tag:
    let
      prefix = builtins.substring 0 4 tag;
      rest = builtins.substring 4 (builtins.stringLength tag - 4) tag;
      validChars = lib.all (c: builtins.match "[a-zA-Z0-9_-]" c != null) (lib.stringToCharacters rest);
    in
    prefix == "tag:" && builtins.stringLength rest > 0 && validChars;

  invalidTags = lib.filter (tag: !validateTag tag) cfg.tags;

in
{
  options.ivali.tailscale = {
    enable = lib.mkEnableOption "Tailscale zero-trust networking";

    authKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        File containing a reusable Tailscale auth key.
        Typically provided through sops-nix.
      '';
    };

    tags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "tag:admin" ];
      example = [ "tag:admin" "tag:infra" "tag:personal" ];
      description = ''
        Tailscale ACL tags to advertise on this node.
        Tags must start with "tag:" and contain only alphanumeric
        characters, hyphens, and underscores.

        When advertiseExitNode is true, tag:exit-node is automatically
        appended unless already present.
      '';
    };

    acceptDns = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Allow Tailscale to manage DNS (MagicDNS split-DNS).

        When enabled, Tailscale registers its MagicDNS resolver
        (100.100.100.100) with systemd-resolved for the tailnet domain only,
        so `<host>.<tailnetDomain>` names resolve without overriding the
        system's global DNS. Safe to leave on; do not use the custom
        tailscale-split-dns service, which fights Tailscale and never applies.
      '';
    };

    magicDnsCheck = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable periodic MagicDNS health checks via systemd timer.
        When enabled, a timer resolves the host's own MagicDNS name and
        reports failures. Disabled by default because tailscale-metrics
        already monitors MagicDNS status continuously, and the timer can
        produce false failures during transient Tailscale restarts.
      '';
    };

    metricsExportInterval = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = ''
        Seconds between Tailscale metrics collections. The metrics exporter
        runs as a proper systemd service with a while-loop that writes to
        a Prometheus text file, served by a lightweight socat HTTP listener.
      '';
    };

    acceptRoutes = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Accept routes advertised by other nodes.
      '';
    };

    advertiseExitNode = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Advertise this machine as an exit node.
        Automatically adds tag:exit-node to the advertised tags.
      '';
    };

    enableTailscaleSsh = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable Tailscale's built-in SSH server.
        When enabled, Tailscale intercepts all port-22 traffic from the
        tailnet and authenticates via its own SSH ACL rules — bypassing
        sshd and authorized_keys entirely.

        Leave disabled if you want regular sshd to handle SSH connections
        (e.g. Shellfish or any client using traditional key auth).
        Enable only if you want the Tailscale admin console SSH feature.
      '';
    };

    tailnetDomain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "codlet-trench.ts.net";
      description = ''
        Tailnet DNS suffix for split DNS.
      '';
    };

    keyExpiryWarningDays = lib.mkOption {
      type = lib.types.int;
      default = 14;
      description = ''
        Number of days before key expiry to start warning.
      '';
    };
  };

  config = lib.mkIf cfg.enable {

    # Validate tags at build time
    assertions = [
      {
        assertion = invalidTags == [ ];
        message = "Invalid Tailscale tags: ${lib.concatStringsSep ", " invalidTags}. Tags must start with 'tag:' and contain only alphanumeric characters, hyphens, and underscores.";
      }
    ];

    #########################################################
    # Tailscale
    #########################################################

    services.tailscale =
      {
        enable = true;

        package = pkgs.tailscale;

        useRoutingFeatures =
          if cfg.advertiseExitNode
          then "both"
          else "client";

        openFirewall = false;

        extraUpFlags =
          [
            "--hostname=${config.networking.hostName}"
            "--advertise-tags=${advertisedTags}"
            "--accept-dns=${lib.boolToString cfg.acceptDns}"
            "--accept-routes=${lib.boolToString cfg.acceptRoutes}"
          ]
          ++ lib.optional cfg.advertiseExitNode "--advertise-exit-node"
          # Only pass --ssh if Tailscale SSH is explicitly opted in.
          # Without this, sshd handles connections via authorized_keys.
          ++ lib.optional cfg.enableTailscaleSsh "--ssh";
      }
      // lib.optionalAttrs (cfg.authKeyFile != null) {
        authKeyFile = cfg.authKeyFile;
      };

    #########################################################
    # Exit Node Routing
    #########################################################

    boot.kernel.sysctl =
      lib.mkIf cfg.advertiseExitNode {
        "net.ipv4.ip_forward" = 1;
        "net.ipv6.conf.all.forwarding" = 1;
      };

    #########################################################
    # Packages
    #########################################################

    environment.systemPackages = [
      pkgs.tailscale
    ];

    #########################################################
    # tailscaled resilience
    #########################################################

    systemd.services.tailscaled = {
      wants = [ "network-online.target" ];

      after = [ "network-online.target" ];

      unitConfig.StartLimitIntervalSec = 0;

      serviceConfig = {
        Restart = "always";
        RestartSec = "5s";
      };
    };

    #########################################################
    # Split DNS
    #########################################################
    #
    # MagicDNS is handled by Tailscale itself: with `acceptDns = true` the
    # tailscaled binary registers its resolver (100.100.100.100) with
    # systemd-resolved for the tailnet routing domain. A previous custom
    # `tailscale-split-dns` service tried to do this with `resolvectl` but
    # never applied (Tailscale reset the link) and left `tailscale0` with no
    # DNS, so `.ts.net` queries fell through to the upstream resolver. It has
    # been removed; do not reintroduce manual split-DNS here.

    #########################################################
    # Key Expiry Monitoring
    #########################################################

    systemd.services.tailscale-key-check = {
      description = "Check Tailscale key expiry";

      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];

      serviceConfig = {
        Type = "oneshot";
      };

      script = ''
        set -euo pipefail

        # Get key expiry info
        EXPIRY_JSON=$(tailscale status --json 2>/dev/null || echo '{}')
        EXPIRY_DATE=$(echo "$EXPIRY_JSON" | ${pkgs.jq}/bin/jq -r '.Self.KeyExpiry // empty' 2>/dev/null || echo "")

        if [ -z "$EXPIRY_DATE" ] || [ "$EXPIRY_DATE" = "none" ]; then
          echo "Key does not expire"
          exit 0
        fi

        # Convert expiry date to epoch
        EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s 2>/dev/null || echo "0")
        NOW_EPOCH=$(date +%s)
        DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))

        echo "Key expires: $EXPIRY_DATE ($DAYS_LEFT days remaining)"

        if [ "$DAYS_LEFT" -le 0 ]; then
          echo "CRITICAL: Key has expired!"
          exit 1
        elif [ "$DAYS_LEFT" -le ${toString cfg.keyExpiryWarningDays} ]; then
          echo "WARNING: Key expires in $DAYS_LEFT days"
          exit 0
        fi
      '';
    };

    systemd.timers.tailscale-key-check = {
      description = "Check Tailscale key expiry daily";
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };

    #########################################################
    # MagicDNS Health Check
    #########################################################

    systemd.services.tailscale-magicdns-check = lib.mkIf (cfg.magicDnsCheck && cfg.tailnetDomain != null) {
      # Disabled by default (see magicDnsCheck option). When enabled,
      # validates MagicDNS resolution. tailscale-metrics already monitors
      # MagicDNS status continuously, so this is only useful as an
      # explicit assertion that the host's own name resolves.
      enable = cfg.magicDnsCheck;
      description = "Check MagicDNS resolution";

      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];

      serviceConfig = {
        Type = "oneshot";
      };

      script = ''
        set -euo pipefail

        # Test MagicDNS resolution
        HOSTNAME=$(tailscale status --json 2>/dev/null | ${pkgs.jq}/bin/jq -r '.Self.DNSName // empty' 2>/dev/null || echo "")

        if [ -z "$HOSTNAME" ]; then
          echo "WARNING: Cannot determine MagicDNS hostname"
          exit 1
        fi

        # Try to resolve own MagicDNS name
        if ${pkgs.host}/bin/host "$HOSTNAME" >/dev/null 2>&1; then
          echo "MagicDNS OK: $HOSTNAME resolves correctly"
        else
          echo "WARNING: MagicDNS resolution failed for $HOSTNAME"
          exit 1
        fi
      '';
    };

    systemd.timers.tailscale-magicdns-check = lib.mkIf (cfg.magicDnsCheck && cfg.tailnetDomain != null) {
      enable = cfg.magicDnsCheck;
      description = "Check MagicDNS resolution hourly";
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnBootSec = "5m";
        OnUnitActiveSec = "1h";
        Persistent = true;
      };
    };

    #########################################################
    # Prometheus Metrics
    #########################################################

    systemd.services.tailscale-metrics = {
      description = "Tailscale Prometheus Metrics";

      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];

      path = [ pkgs.jq pkgs.host pkgs.tailscale pkgs.bash pkgs.coreutils pkgs.socat ];

      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = "10s";
        KillMode = "control-group";
        # Hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/var/lib/tailscale-metrics" ];
        StateDirectory = "tailscale-metrics";
      };

      preStart = ''
        set -euo pipefail
        METRICS_FILE="/var/lib/tailscale-metrics/metrics.prom"

        # Write initial metrics to avoid serving an empty file
        TIMESTAMP=$(date +%s)
        EXPIRY_JSON=$(tailscale status --json 2>/dev/null || echo '{}')
        EXPIRY_DATE=$(echo "$EXPIRY_JSON" | jq -r '.Self.KeyExpiry // empty' 2>/dev/null || echo "")
        HOSTNAME=$(echo "$EXPIRY_JSON" | jq -r '.Self.HostName // empty' 2>/dev/null || echo "unknown")
        Connected=$(echo "$EXPIRY_JSON" | jq -r '.Self.BackendState // empty' 2>/dev/null || echo "unknown")

        KEY_EXPIRY_DAYS=999
        if [ -n "$EXPIRY_DATE" ] && [ "$EXPIRY_DATE" != "none" ]; then
          EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s 2>/dev/null || echo "0")
          NOW_EPOCH=$(date +%s)
          KEY_EXPIRY_DAYS=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))
        fi

        DNSNAME=$(echo "$EXPIRY_JSON" | jq -r '.Self.DNSName // empty' 2>/dev/null || echo "")
        MAGICDNS_STATUS=1
        if [ -n "$DNSNAME" ]; then
          if ! host "$DNSNAME" >/dev/null 2>&1; then
            MAGICDNS_STATUS=0
          fi
        fi

        CONNECTED_VAL=$(if [ "$Connected" = "Running" ]; then echo 1; else echo 0; fi)
        {
          echo "# HELP tailscale_connected Tailscale connection status (1=connected, 0=disconnected)"
          echo "# TYPE tailscale_connected gauge"
          echo "tailscale_connected{host=\"$HOSTNAME\"} $CONNECTED_VAL"
          echo "# HELP tailscale_key_expiry_days Days until Tailscale key expires"
          echo "# TYPE tailscale_key_expiry_days gauge"
          echo "tailscale_key_expiry_days{host=\"$HOSTNAME\"} $KEY_EXPIRY_DAYS"
          echo "# HELP tailscale_magicdns_status MagicDNS resolution status (1=ok, 0=failed)"
          echo "# TYPE tailscale_magicdns_status gauge"
          echo "tailscale_magicdns_status{host=\"$HOSTNAME\"} $MAGICDNS_STATUS"
          echo "# HELP tailscale_metrics_timestamp Unix timestamp of last metrics collection"
          echo "# TYPE tailscale_metrics_timestamp gauge"
          echo "tailscale_metrics_timestamp{host=\"$HOSTNAME\"} $TIMESTAMP"
        } > "$METRICS_FILE"
      '';

      script = ''
        set -euo pipefail
        METRICS_FILE="/var/lib/tailscale-metrics/metrics.prom"
        INTERVAL=${toString cfg.metricsExportInterval}

        # Background: update metrics every N seconds
        (
          while true; do
            sleep "$INTERVAL"
            TIMESTAMP=$(date +%s)
            EXPIRY_JSON=$(tailscale status --json 2>/dev/null || echo '{}')
            EXPIRY_DATE=$(echo "$EXPIRY_JSON" | jq -r '.Self.KeyExpiry // empty' 2>/dev/null || echo "")
            HOSTNAME=$(echo "$EXPIRY_JSON" | jq -r '.Self.HostName // empty' 2>/dev/null || echo "unknown")
            Connected=$(echo "$EXPIRY_JSON" | jq -r '.Self.BackendState // empty' 2>/dev/null || echo "unknown")

            KEY_EXPIRY_DAYS=999
            if [ -n "$EXPIRY_DATE" ] && [ "$EXPIRY_DATE" != "none" ]; then
              EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s 2>/dev/null || echo "0")
              NOW_EPOCH=$(date +%s)
              KEY_EXPIRY_DAYS=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))
            fi

            DNSNAME=$(echo "$EXPIRY_JSON" | jq -r '.Self.DNSName // empty' 2>/dev/null || echo "")
            MAGICDNS_STATUS=1
            if [ -n "$DNSNAME" ]; then
              if ! host "$DNSNAME" >/dev/null 2>&1; then
                MAGICDNS_STATUS=0
              fi
            fi

            CONNECTED_VAL=$(if [ "$Connected" = "Running" ]; then echo 1; else echo 0; fi)

            # Connection quality: count online peers and sum throughput
            PEER_COUNT=$(echo "$EXPIRY_JSON" | jq '[.Peer[] | select(.Online == true)] | length' 2>/dev/null || echo "0")
            TOTAL_PEERS=$(echo "$EXPIRY_JSON" | jq '[.Peer[]] | length' 2>/dev/null || echo "0")
            TX_BYTES=$(echo "$EXPIRY_JSON" | jq '.Self.TxnBytes // 0' 2>/dev/null || echo "0")
            RX_BYTES=$(echo "$EXPIRY_JSON" | jq '.Self.RxBytes // 0' 2>/dev/null || echo "0")

            {
              echo "# HELP tailscale_connected Tailscale connection status (1=connected, 0=disconnected)"
              echo "# TYPE tailscale_connected gauge"
              echo "tailscale_connected{host=\"$HOSTNAME\"} $CONNECTED_VAL"
              echo "# HELP tailscale_key_expiry_days Days until Tailscale key expires"
              echo "# TYPE tailscale_key_expiry_days gauge"
              echo "tailscale_key_expiry_days{host=\"$HOSTNAME\"} $KEY_EXPIRY_DAYS"
              echo "# HELP tailscale_magicdns_status MagicDNS resolution status (1=ok, 0=failed)"
              echo "# TYPE tailscale_magicdns_status gauge"
              echo "tailscale_magicdns_status{host=\"$HOSTNAME\"} $MAGICDNS_STATUS"
              echo "# HELP tailscale_peers_online Number of online Tailscale peers"
              echo "# TYPE tailscale_peers_online gauge"
              echo "tailscale_peers_online{host=\"$HOSTNAME\"} $PEER_COUNT"
              echo "# HELP tailscale_peers_total Total number of Tailscale peers"
              echo "# TYPE tailscale_peers_total gauge"
              echo "tailscale_peers_total{host=\"$HOSTNAME\"} $TOTAL_PEERS"
              echo "# HELP tailscale_tx_bytes Total bytes transmitted"
              echo "# TYPE tailscale_tx_bytes counter"
              echo "tailscale_tx_bytes{host=\"$HOSTNAME\"} $TX_BYTES"
              echo "# HELP tailscale_rx_bytes Total bytes received"
              echo "# TYPE tailscale_rx_bytes counter"
              echo "tailscale_rx_bytes{host=\"$HOSTNAME\"} $RX_BYTES"
              echo "# HELP tailscale_metrics_timestamp Unix timestamp of last metrics collection"
              echo "# TYPE tailscale_metrics_timestamp gauge"
              echo "tailscale_metrics_timestamp{host=\"$HOSTNAME\"} $TIMESTAMP"
            } > "$METRICS_FILE"
          done
        ) &
        UPDATE_PID=$!

        # Foreground: serve metrics via socat
        socat TCP-LISTEN:9121,fork,reuseaddr,bind=127.0.0.1 SYSTEM:'echo "HTTP/1.1 200 OK"; echo "Content-Type: text/plain; version=0.0.4"; echo ""; cat /var/lib/tailscale-metrics/metrics.prom' &
        SOCAT_PID=$!

        # Wait for either to exit
        wait -n $UPDATE_PID $SOCAT_PID 2>/dev/null || true
        kill $UPDATE_PID $SOCAT_PID 2>/dev/null || true
        exit 1
      '';
    };

    systemd.timers.tailscale-metrics = {
      description = "Start Tailscale metrics collection";
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnBootSec = "1m";
        OnUnitActiveSec = "1m";
        Persistent = true;
      };
    };

    # Metrics are served on 127.0.0.1:9121 (loopback only).
    # Prometheus scrapes locally, so no external firewall rule is needed.
    # Removed: networking.firewall.allowedTCPPorts = [ 9121 ];

    # Add to Prometheus scrape targets
    services.prometheus.scrapeConfigs = [
      {
        job_name = "tailscale";
        static_configs = [
          {
            targets = [ "127.0.0.1:9121" ];
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

