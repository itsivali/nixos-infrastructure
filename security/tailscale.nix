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

    systemd.services.tailscale-magicdns-check = lib.mkIf (cfg.tailnetDomain != null) {
      # Intentionally disabled. MagicDNS now resolves correctly because
      # Tailscale manages DNS (`acceptDns = true` registers 100.100.100.100 as
      # the resolver for the tailnet routing domain via systemd-resolved).
      # This check is kept off so a transient Tailscale-down during a
      # `nixos-rebuild switch` cannot make the switch report exit 4. MagicDNS
      # health is still monitored continuously by tailscale-metrics
      # (tailscale_magicdns_status).
      enable = false;
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

    systemd.timers.tailscale-magicdns-check = lib.mkIf (cfg.tailnetDomain != null) {
      # Disabled along with the service (see tailscale-magicdns-check above).
      enable = false;
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

      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = 30;
      };

      script = ''
        set -euo pipefail

        METRICS_FILE="/var/lib/tailscale-metrics/metrics.prom"
        mkdir -p /var/lib/tailscale-metrics

        while true; do
          TIMESTAMP=$(date +%s)

          # Get key expiry info
          EXPIRY_JSON=$(tailscale status --json 2>/dev/null || echo '{}')
          EXPIRY_DATE=$(echo "$EXPIRY_JSON" | ${pkgs.jq}/bin/jq -r '.Self.KeyExpiry // empty' 2>/dev/null || echo "")
          HOSTNAME=$(echo "$EXPIRY_JSON" | ${pkgs.jq}/bin/jq -r '.Self.HostName // empty' 2>/dev/null || echo "unknown")
          Connected=$(echo "$EXPIRY_JSON" | ${pkgs.jq}/bin/jq -r '.BackendState // empty' 2>/dev/null || echo "unknown")

          # Calculate days until expiry
          KEY_EXPIRY_DAYS=999
          if [ -n "$EXPIRY_DATE" ] && [ "$EXPIRY_DATE" != "none" ]; then
            EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s 2>/dev/null || echo "0")
            NOW_EPOCH=$(date +%s)
            KEY_EXPIRY_DAYS=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))
          fi

          # MagicDNS check status — resolve this node's own MagicDNS name
          # (e.g. prague-1.codlet-trench.ts.net), which is what MagicDNS
          # actually serves. The bare tailnet domain does not resolve.
          DNSNAME=$(echo "$EXPIRY_JSON" | ${pkgs.jq}/bin/jq -r '.Self.DNSName // empty' 2>/dev/null || echo "")
          MAGICDNS_STATUS=1
          if [ -n "$DNSNAME" ]; then
            if ! ${pkgs.host}/bin/host "$DNSNAME" >/dev/null 2>&1; then
              MAGICDNS_STATUS=0
            fi
          fi

          # Write metrics
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

          sleep 60
        done
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

    # Expose metrics port
    networking.firewall.allowedTCPPorts = [ 9121 ];

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

