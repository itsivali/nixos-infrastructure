##############################################################################
#
# Security Tailscale
#
# Purpose
# -------
# Configures Tailscale zero-trust networking with optional exit-node
# advertising, MagicDNS, Tailscale SSH, key-expiry monitoring, and
# Prometheus metrics collection.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Enable and configure Tailscale with auth key, tags, and routing features
# - Manage exit-node routing through kernel IP forwarding
# - Configure tailscaled systemd resilience and firewall backend selection
# - Monitor key expiry through a daily systemd timer
# - Optionally monitor MagicDNS resolution
# - Export connection, peer, key-expiry, and exit-node metrics
# - Validate advertised tag formats at evaluation time
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.tailscale;

  tailscaleBin = "${pkgs.tailscale}/bin/tailscale";
  jqBin = "${pkgs.jq}/bin/jq";
  hostBin = "${pkgs.host}/bin/host";

  # Append tag:exit-node when exit-node advertising is enabled.
  effectiveTags =
    cfg.tags
    ++ lib.optional
      (
        cfg.advertiseExitNode
        && !(builtins.elem "tag:exit-node" cfg.tags)
      ) "tag:exit-node";

  advertisedTags = lib.concatStringsSep "," effectiveTags;

  # Tags must start with "tag:" and contain a non-empty suffix
  # consisting only of alphanumeric characters, hyphens, or underscores.
  validateTag = tag:
    let
      validPrefix = lib.hasPrefix "tag:" tag;
      rest =
        if validPrefix
        then builtins.substring 4 (builtins.stringLength tag - 4) tag
        else "";
      validChars =
        lib.all
          (character:
            builtins.match "[a-zA-Z0-9_-]" character != null
          )
          (lib.stringToCharacters rest);
    in
    validPrefix
    && builtins.stringLength rest > 0
    && validChars;

  invalidTags = lib.filter (tag: !validateTag tag) cfg.tags;

  tailscaleEnabled = cfg.enable;

  metricsIntervalValid = cfg.metricsExportInterval >= 15;
  keyWarningDaysValid = cfg.keyExpiryWarningDays >= 0;

  metricsDirectory = "/var/lib/tailscale-metrics";
  metricsFile = "${metricsDirectory}/metrics.prom";

in
{
  options.ivali.tailscale = {
    enable = lib.mkEnableOption "Tailscale zero-trust networking";

    authKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        File containing a Tailscale authentication key.
        Typically provided through sops-nix.

        The file must be readable by the Tailscale service and must not
        be committed in plaintext to the repository.
      '';
    };

    tags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "tag:admin" ];
      example = [
        "tag:admin"
        "tag:infra"
        "tag:personal"
      ];
      description = ''
        Tailscale ACL tags advertised by this node.

        Tags must start with "tag:" and contain only alphanumeric
        characters, hyphens, and underscores.

        When advertiseExitNode is enabled, tag:exit-node is appended
        automatically unless it is already present.
      '';
    };

    acceptDns = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Allow Tailscale to manage DNS integration for MagicDNS.

        When enabled, Tailscale manages the appropriate DNS configuration
        for the tailnet. Avoid introducing a competing custom split-DNS
        service that repeatedly overwrites Tailscale-managed settings.
      '';
    };

    magicDnsCheck = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable periodic MagicDNS health checks.

        The check resolves this machine's own Tailscale DNS name.
        It is disabled by default to avoid false alarms during transient
        network or Tailscale restarts.
      '';
    };

    metricsExportInterval = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = ''
        Interval in seconds between Tailscale metrics collections.

        Values below 15 seconds are rejected to avoid unnecessary
        background activity on resource-constrained machines.
      '';
    };

    acceptRoutes = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Accept routes advertised by other Tailscale nodes.
      '';
    };

    advertiseExitNode = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Advertise this machine as a Tailscale exit node.

        Enables IPv4 and IPv6 forwarding and automatically appends
        tag:exit-node to the advertised tags.
      '';
    };

    enableTailscaleSsh = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable Tailscale SSH.

        When disabled, normal OpenSSH handles SSH connections using
        authorized_keys and the configured sshd policy.

        Enable only when Tailscale SSH ACL-based access is intended.
      '';
    };

    tailnetDomain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "codlet-trench.ts.net";
      description = ''
        Tailnet DNS suffix used by the optional MagicDNS health check.
      '';
    };

    keyExpiryWarningDays = lib.mkOption {
      type = lib.types.int;
      default = 14;
      description = ''
        Number of days before key expiry at which the monitoring service
        emits a warning.
      '';
    };
  };

  config = lib.mkIf tailscaleEnabled {
    assertions = [
      {
        assertion = invalidTags == [ ];
        message =
          "Invalid Tailscale tags: "
          + lib.concatStringsSep ", " invalidTags
          + ". Tags must start with 'tag:' and contain only "
          + "alphanumeric characters, hyphens, and underscores.";
      }
      {
        assertion = metricsIntervalValid;
        message =
          "ivali.tailscale.metricsExportInterval must be at least 15 seconds.";
      }
      {
        assertion = keyWarningDaysValid;
        message =
          "ivali.tailscale.keyExpiryWarningDays must be non-negative.";
      }
    ];

    ##########################################################################
    # Tailscale daemon
    ##########################################################################

    services.tailscale = {
      enable = true;
      package = pkgs.tailscale;

      useRoutingFeatures =
        if cfg.advertiseExitNode
        then "both"
        else "client";

      # Firewall management is declarative in security/firewall.nix.
      openFirewall = false;

      extraUpFlags =
        [
          "--hostname=${config.networking.hostName}"
          "--advertise-tags=${advertisedTags}"
          "--accept-dns=${lib.boolToString cfg.acceptDns}"
          "--accept-routes=${lib.boolToString cfg.acceptRoutes}"
        ]
        ++ lib.optional cfg.advertiseExitNode "--advertise-exit-node"
        ++ lib.optional cfg.enableTailscaleSsh "--ssh";
    } // lib.optionalAttrs (cfg.authKeyFile != null) {
      authKeyFile = cfg.authKeyFile;
    };

    ##########################################################################
    # Tailscaled resilience and firewall backend
    ##########################################################################

    systemd.services.tailscaled = {
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      unitConfig.StartLimitIntervalSec = 0;

      serviceConfig = {
        Restart = "always";
        RestartSec = "5s";

        # Diagnostic workaround for the observed failure in which Tailscale
        # selects its iptables backend but cannot insert its NAT rule because
        # nat/POSTROUTING is missing.
        #
        # TS_DEBUG_FIREWALL_MODE is a Tailscale debug override. Confirm that
        # the installed Tailscale release supports this value before relying
        # on it. Remove this override if it is unsupported or ineffective.
        Environment = [
          "TS_DEBUG_FIREWALL_MODE=nftables"
        ];
      };
    };

    ##########################################################################
    # Exit-node routing
    ##########################################################################

    boot.kernel.sysctl = lib.mkIf cfg.advertiseExitNode {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };

    ##########################################################################
    # Packages
    ##########################################################################

    environment.systemPackages = [
      pkgs.tailscale
    ];

    ##########################################################################
    # Key expiry monitoring
    ##########################################################################

    systemd.services.tailscale-key-check = {
      description = "Check Tailscale key expiry";
      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };

      script = ''
        set -euo pipefail

        EXPIRY_JSON="$(${tailscaleBin} status --json 2>/dev/null || echo '{}')"

        EXPIRY_DATE="$(
          printf '%s' "$EXPIRY_JSON" \
            | ${jqBin} -r '.Self.KeyExpiry // empty' 2>/dev/null \
            || true
        )"

        if [ -z "$EXPIRY_DATE" ] || [ "$EXPIRY_DATE" = "none" ]; then
          echo "No expiring node key reported by Tailscale."
          exit 0
        fi

        EXPIRY_EPOCH="$(date -d "$EXPIRY_DATE" +%s 2>/dev/null || echo 0)"
        NOW_EPOCH="$(date +%s)"

        if [ "$EXPIRY_EPOCH" -le 0 ]; then
          echo "WARNING: Could not parse Tailscale key expiry date."
          exit 1
        fi

        DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))

        echo "Tailscale key expiry: $EXPIRY_DATE ($DAYS_LEFT days remaining)"

        if [ "$DAYS_LEFT" -le 0 ]; then
          echo "CRITICAL: Tailscale node key has expired."
          exit 1
        elif [ "$DAYS_LEFT" -le ${toString cfg.keyExpiryWarningDays} ]; then
          echo "WARNING: Tailscale key expires within the configured warning window."
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

    ##########################################################################
    # Optional MagicDNS health check
    ##########################################################################

    systemd.services.tailscale-magicdns-check =
      lib.mkIf (cfg.magicDnsCheck && cfg.tailnetDomain != null) {
        description = "Check Tailscale MagicDNS resolution";
        after = [ "tailscaled.service" ];
        wants = [ "tailscaled.service" ];

        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };

        script = ''
          set -euo pipefail

          STATUS_JSON="$(${tailscaleBin} status --json 2>/dev/null || echo '{}')"

          DNS_NAME="$(
            printf '%s' "$STATUS_JSON" \
              | ${jqBin} -r '.Self.DNSName // empty' 2>/dev/null \
              || true
          )"

          if [ -z "$DNS_NAME" ]; then
            echo "WARNING: Tailscale did not return this node's DNS name."
            exit 1
          fi

          if ${hostBin} "$DNS_NAME" >/dev/null 2>&1; then
            echo "MagicDNS OK: $DNS_NAME resolves."
          else
            echo "WARNING: MagicDNS resolution failed for $DNS_NAME."
            exit 1
          fi
        '';
      };

    systemd.timers.tailscale-magicdns-check =
      lib.mkIf (cfg.magicDnsCheck && cfg.tailnetDomain != null) {
        description = "Check Tailscale MagicDNS resolution hourly";
        wantedBy = [ "timers.target" ];

        timerConfig = {
          OnBootSec = "5m";
          OnUnitActiveSec = "1h";
          Persistent = true;
        };
      };

    ##########################################################################
    # Prometheus metrics
    ##########################################################################

    systemd.services.tailscale-metrics = {
      description = "Tailscale Prometheus metrics exporter";
      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];

      path = [
        pkgs.jq
        pkgs.host
        pkgs.tailscale
        pkgs.bash
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.socat
      ];

      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = "10s";
        KillMode = "control-group";

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;

        ReadWritePaths = [ metricsDirectory ];
        StateDirectory = "tailscale-metrics";
      };

      script = ''
        set -euo pipefail

        METRICS_FILE="${metricsFile}"
        INTERVAL=${toString cfg.metricsExportInterval}

        write_metrics() {
          local timestamp expiry_json expiry_date hostname backend_state
          local key_expiry_days dns_name magicdns_status
          local exit_node_status exit_node_configured
          local connected_val peer_count total_peers tx_bytes rx_bytes
          local temp_file

          timestamp="$(date +%s)"
          expiry_json="$(${tailscaleBin} status --json 2>/dev/null || echo '{}')"

          expiry_date="$(
            printf '%s' "$expiry_json" \
              | ${jqBin} -r '.Self.KeyExpiry // empty' 2>/dev/null \
              || true
          )"

          hostname="$(
            printf '%s' "$expiry_json" \
              | ${jqBin} -r '.Self.HostName // "unknown"' 2>/dev/null \
              || echo unknown
          )"

          backend_state="$(
            printf '%s' "$expiry_json" \
              | ${jqBin} -r '.Self.BackendState // "unknown"' 2>/dev/null \
              || echo unknown
          )"

          key_expiry_days=999

          if [ -n "$expiry_date" ] && [ "$expiry_date" != "none" ]; then
            local expiry_epoch now_epoch
            expiry_epoch="$(date -d "$expiry_date" +%s 2>/dev/null || echo 0)"
            now_epoch="$(date +%s)"

            if [ "$expiry_epoch" -gt 0 ]; then
              key_expiry_days=$(( (expiry_epoch - now_epoch) / 86400 ))
            fi
          fi

          dns_name="$(
            printf '%s' "$expiry_json" \
              | ${jqBin} -r '.Self.DNSName // empty' 2>/dev/null \
              || true
          )"

          magicdns_status=1
          if [ -n "$dns_name" ] && ! ${hostBin} "$dns_name" >/dev/null 2>&1; then
            magicdns_status=0
          fi

          connected_val=0
          if [ "$backend_state" = "Running" ]; then
            connected_val=1
          fi

          peer_count="$(
            printf '%s' "$expiry_json" \
              | ${jqBin} '[.Peer[]? | select(.Online == true)] | length' \
                2>/dev/null || echo 0
          )"

          total_peers="$(
            printf '%s' "$expiry_json" \
              | ${jqBin} '[.Peer[]?] | length' 2>/dev/null || echo 0
          )"

          tx_bytes="$(
            printf '%s' "$expiry_json" \
              | ${jqBin} -r '.Self.TxnBytes // 0' 2>/dev/null || echo 0
          )"

          rx_bytes="$(
            printf '%s' "$expiry_json" \
              | ${jqBin} -r '.Self.RxBytes // 0' 2>/dev/null || echo 0
          )"

          exit_node_status=0
          if ${tailscaleBin} debug prefs 2>/dev/null \
            | ${jqBin} -r '.AdvertiseRoutes[]?' 2>/dev/null \
            | ${pkgs.gnugrep}/bin/grep -qE '^(0\.0\.0\.0/0|::/0)$'; then
            exit_node_status=1
          fi

          exit_node_configured=${if cfg.advertiseExitNode then "1" else "0"}

          # Write to a temporary file and atomically replace the metrics file.
          # This prevents scrapers from reading a partially written document.
          temp_file="$(mktemp "${metricsDirectory}/metrics.XXXXXX")"

          {
            echo "# HELP tailscale_connected Tailscale connection status"
            echo "# TYPE tailscale_connected gauge"
            echo "tailscale_connected{host=\"$hostname\"} $connected_val"

            echo "# HELP tailscale_key_expiry_days Days until key expiry"
            echo "# TYPE tailscale_key_expiry_days gauge"
            echo "tailscale_key_expiry_days{host=\"$hostname\"} $key_expiry_days"

            echo "# HELP tailscale_magicdns_status MagicDNS resolution status"
            echo "# TYPE tailscale_magicdns_status gauge"
            echo "tailscale_magicdns_status{host=\"$hostname\"} $magicdns_status"

            echo "# HELP tailscale_exit_node_configured Exit node configured in NixOS"
            echo "# TYPE tailscale_exit_node_configured gauge"
            echo "tailscale_exit_node_configured{host=\"$hostname\"} $exit_node_configured"

            echo "# HELP tailscale_exit_node_advertised Exit node routes advertised"
            echo "# TYPE tailscale_exit_node_advertised gauge"
            echo "tailscale_exit_node_advertised{host=\"$hostname\"} $exit_node_status"

            echo "# HELP tailscale_peers_online Number of online peers"
            echo "# TYPE tailscale_peers_online gauge"
            echo "tailscale_peers_online{host=\"$hostname\"} $peer_count"

            echo "# HELP tailscale_peers_total Number of known peers"
            echo "# TYPE tailscale_peers_total gauge"
            echo "tailscale_peers_total{host=\"$hostname\"} $total_peers"

            echo "# HELP tailscale_tx_bytes Total transmitted bytes"
            echo "# TYPE tailscale_tx_bytes counter"
            echo "tailscale_tx_bytes{host=\"$hostname\"} $tx_bytes"

            echo "# HELP tailscale_rx_bytes Total received bytes"
            echo "# TYPE tailscale_rx_bytes counter"
            echo "tailscale_rx_bytes{host=\"$hostname\"} $rx_bytes"

            echo "# HELP tailscale_metrics_timestamp Unix timestamp of last collection"
            echo "# TYPE tailscale_metrics_timestamp gauge"
            echo "tailscale_metrics_timestamp{host=\"$hostname\"} $timestamp"
          } > "$temp_file"

          chmod 0644 "$temp_file"
          mv -f "$temp_file" "$METRICS_FILE"
        }

        # Create initial metrics before opening the listener.
        write_metrics

        # Serve metrics only on loopback. Prometheus scrapes locally.
        # socat is restarted by systemd if the service fails.
        (
          while true; do
            sleep "$INTERVAL"
            write_metrics
          done
        ) &
        updater_pid=$!

        cleanup() {
          kill "$updater_pid" 2>/dev/null || true
          wait "$updater_pid" 2>/dev/null || true
        }
        trap cleanup EXIT INT TERM

        exec ${pkgs.socat}/bin/socat \
          TCP-LISTEN:9121,fork,reuseaddr,bind=127.0.0.1 \
          SYSTEM:'printf "HTTP/1.1 200 OK\r\nContent-Type: text/plain; version=0.0.4\r\nConnection: close\r\n\r\n"; cat ${metricsFile}'
      '';
    };

    # Metrics exporter starts as a service; no public firewall port is opened.
    # Scrape-target registration remains centralized in observability/prometheus.nix.
  };
}

