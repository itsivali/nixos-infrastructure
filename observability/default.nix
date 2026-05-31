# observability/default.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.observability;
  lokiListenAddress      = "127.0.0.1";
  lokiPort               = 3100;
  prometheusListenAddress = "127.0.0.1";
  prometheusPort         = 9090;
  grafanaListenAddress   = "127.0.0.1";
  grafanaPort            = 3000;
  # Resolve the OTel package name across nixpkgs versions.
  otelCollector =
    pkgs.opentelemetry-collector-contrib or
    pkgs.otelcol-contrib or
    pkgs.opentelemetry-collector;
in
{
  # ── option declarations ──────────────────────────────────────────────────────
  options.ivali.observability = {
    enable = lib.mkOption {
      type    = lib.types.bool;
      default = true;
      description = "Enable the local laptop monitoring stack.";
    };
    falco.enable   = lib.mkEnableOption "Falco runtime detection";
    promtail.enable = lib.mkOption {
      type    = lib.types.bool;
      default = true;
      description = "Forward systemd journal logs into local Loki.";
    };
    otel.enable = lib.mkEnableOption "OpenTelemetry collector";
    lokiUrl = lib.mkOption {
      type    = lib.types.str;
      default = "http://${lokiListenAddress}:${toString lokiPort}/loki/api/v1/push";
      description = "Loki push endpoint for Promtail.";
    };
  };

  # ── configuration ────────────────────────────────────────────────────────────
  # Everything lives inside `config` so that `options` and `config` are the
  # only two top-level keys — the structure NixOS modules require.
  # Conditional blocks use lib.mkIf; unconditional items (journald, audit) are
  # always applied when the module is imported.
  config = {

    # packages always present when this module is imported
    environment.systemPackages = with pkgs; [
      grafana-loki
      promtail
      syft
      trivy
    ] ++ lib.optionals cfg.falco.enable [ pkgs.falco ]
      ++ lib.optionals cfg.otel.enable  [ otelCollector ];

    # ── Loki ──────────────────────────────────────────────────────────────────
    services.loki = lib.mkIf cfg.enable {
      enable = true;
      configuration = {
        auth_enabled = false;
        server = {
          http_listen_address = lokiListenAddress;
          http_listen_port    = lokiPort;
          grpc_listen_port    = 0;
        };
        common = {
          path_prefix = "/var/lib/loki";
          storage.filesystem = {
            chunks_directory = "/var/lib/loki/chunks";
            rules_directory  = "/var/lib/loki/rules";
          };
          replication_factor = 1;
          ring.kvstore.store = "inmemory";
        };
        schema_config.configs = [
          {
            from         = "2024-01-01";
            store        = "tsdb";
            object_store = "filesystem";
            schema       = "v13";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }
        ];
        limits_config = {
          allow_structured_metadata = false;
          retention_period          = "168h";
        };
        compactor = {
          working_directory    = "/var/lib/loki/compactor";
          retention_enabled    = true;
          delete_request_store = "filesystem";
        };
        analytics.reporting_enabled = false;
      };
    };

    # ── Prometheus (single attribute set — exporters.node merged in here) ─────
    services.prometheus = lib.mkIf cfg.enable {
      enable          = true;
      listenAddress   = prometheusListenAddress;
      port            = prometheusPort;
      retentionTime   = "15d";
      globalConfig = {
        scrape_interval     = "15s";
        evaluation_interval = "15s";
      };
      scrapeConfigs = [
        {
          job_name = "node";
          static_configs = [
            { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ]; }
          ];
        }
        {
          job_name = "prometheus";
          static_configs = [
            { targets = [ "${prometheusListenAddress}:${toString prometheusPort}" ]; }
          ];
        }
      ];
      # exporters.node lives here — NOT as a separate top-level attribute.
      # Defining services.prometheus a second time with = would shadow the
      # first definition and cause "attribute already defined" errors.
      exporters.node = {
        enable             = true;
        enabledCollectors  = [ "systemd" "processes" ];
        openFirewall       = false;
      };
    };

    # ── Grafana ───────────────────────────────────────────────────────────────
    services.grafana = lib.mkIf cfg.enable {
      enable = true;
      settings = {
        server = {
          http_addr = grafanaListenAddress;
          http_port = grafanaPort;
          domain    = "localhost";
        };
        analytics.reporting_enabled = false;
        security = {
        admin_user = "admin";
        admin_password = "admin";
        disable_gravatar = true;

        # Required by NixOS 26.05+
        secret_key = "SW2YcwTIb9zpOOhoPsMm";
        };
      };
      provision = {
        enable = true;
        datasources.settings = {
          apiVersion  = 1;
          datasources = [
            {
              name      = "Prometheus";
              type      = "prometheus";
              access    = "proxy";
              url       = "http://${prometheusListenAddress}:${toString prometheusPort}";
              isDefault = true;
            }
            {
              name   = "Loki";
              type   = "loki";
              access = "proxy";
              url    = "http://${lokiListenAddress}:${toString lokiPort}";
            }
          ];
        };
      };
    };

    # ── audit (unconditional — security hardening always active) ─────────────
    security.audit = {
      enable = true;
      rules = [
        "-w /etc/passwd -p wa -k identity"
        "-w /etc/shadow -p wa -k identity"
        "-w /etc/group -p wa -k identity"
        "-w /etc/gshadow -p wa -k identity"
        "-w /etc/sudoers -p wa -k sudoers"
        "-w /run/current-system/sw/bin/sudo -p x -k priv_esc"
        "-w /etc/ssh/ -p wa -k ssh"
        "-w /etc/systemd/system/ -p wa -k systemd"
        "-a always,exit -F arch=b64 -S execve -k exec"
        "-a always,exit -F arch=b32 -S execve -k exec"
        "-e 2"
      ];
    };
    security.auditd.enable = true;

    # ── journald (unconditional) ──────────────────────────────────────────────
    services.journald.extraConfig = ''
      Storage=persistent
      Compress=yes
      ForwardToSyslog=no
      RateLimitIntervalSec=30s
      RateLimitBurst=10000
    '';

    # ── Falco (conditional on falco.enable) ───────────────────────────────────
    systemd.services.falco = lib.mkIf cfg.falco.enable {
      description = "Falco runtime security detection";
      wantedBy    = [ "multi-user.target" ];
      after       = [ "network.target" ];
      serviceConfig = {
        ExecStart  = "${pkgs.falco}/bin/falco --modern-bpf";
        Restart    = "always";
        RestartSec = "10s";
      };
    };

    

    # ── Promtail ──────────────────────────────────────────────────────────────
    environment.etc."promtail/config.yml" = lib.mkIf (cfg.enable && cfg.promtail.enable) {
      text = ''
        server:
          http_listen_port: 9080
          grpc_listen_port: 0
        positions:
          filename: /var/lib/promtail/positions.yaml
        clients:
          - url: ${cfg.lokiUrl}
        scrape_configs:
          - job_name: journal
            journal:
              max_age: 12h
              labels:
                job: systemd-journal
                host: ${config.networking.hostName}
            relabel_configs:
              - source_labels: ['__journal__systemd_unit']
                target_label: unit
      '';
    };

    systemd.services.promtail = lib.mkIf (cfg.enable && cfg.promtail.enable) {
      description = "Promtail journal shipper";
      wantedBy    = [ "multi-user.target" ];
      after       = [ "network-online.target" "loki.service" ];
      wants       = [ "network-online.target" "loki.service" ];
      serviceConfig = {
        ExecStart  = "${pkgs.promtail}/bin/promtail -config.file=/etc/promtail/config.yml";
        Restart    = "always";
        RestartSec = "10s";
        StateDirectory = "promtail";
      };
    };

    # ── OpenTelemetry collector ───────────────────────────────────────────────
    systemd.services.opentelemetry-collector = lib.mkIf cfg.otel.enable {
      description = "OpenTelemetry collector";
      wantedBy    = [ "multi-user.target" ];
      after       = [ "network-online.target" ];
      wants       = [ "network-online.target" ];
      serviceConfig = {
        ExecStart  = "${otelCollector}/bin/otelcol --config=/etc/otelcol/config.yaml";
        Restart    = "always";
        RestartSec = "10s";
      };
    };

    environment.etc."otelcol/config.yaml" = lib.mkIf cfg.otel.enable {
      text = ''
        receivers:
          otlp:
            protocols:
              grpc:
              http:
        processors:
          batch:
        exporters:
          logging:
            verbosity: basic
        service:
          pipelines:
            traces:
              receivers: [otlp]
              processors: [batch]
              exporters: [logging]
            metrics:
              receivers: [otlp]
              processors: [batch]
              exporters: [logging]
      '';
    };

  }; # end config
}