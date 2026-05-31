{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.observability;
  otelCollector = pkgs.opentelemetry-collector-contrib or pkgs.otelcol-contrib or pkgs.opentelemetry-collector;
in
{
  options.ivali.observability = {
    falco.enable = lib.mkEnableOption "Falco runtime detection";
    promtail.enable = lib.mkEnableOption "Promtail journal forwarding";
    otel.enable = lib.mkEnableOption "OpenTelemetry collector";
    lokiUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:3100/loki/api/v1/push";
      description = "Loki push endpoint for Promtail.";
    };
  };

  environment.systemPackages = with pkgs; [
    falco
    grafana-loki
    otelCollector
    promtail
    syft
    trivy
  ];

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

  services.prometheus.exporters.node = {
    enable = true;
    enabledCollectors = [ "systemd" "processes" ];
    openFirewall = false;
  };

  systemd.journald.extraConfig = ''
    Storage=persistent
    Compress=yes
    ForwardToSyslog=no
    RateLimitIntervalSec=30s
    RateLimitBurst=10000
  '';

  systemd.services.falco = lib.mkIf cfg.falco.enable {
    description = "Falco runtime security detection";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.falco}/bin/falco --modern-bpf";
      Restart = "always";
      RestartSec = "10s";
    };
  };

  environment.etc."promtail/config.yml" = lib.mkIf cfg.promtail.enable {
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

  systemd.services.promtail = lib.mkIf cfg.promtail.enable {
    description = "Promtail journal shipper";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.promtail}/bin/promtail -config.file=/etc/promtail/config.yml";
      Restart = "always";
      RestartSec = "10s";
      StateDirectory = "promtail";
    };
  };

  systemd.services.opentelemetry-collector = lib.mkIf cfg.otel.enable {
    description = "OpenTelemetry collector";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      ExecStart = "${otelCollector}/bin/otelcol --config=/etc/otelcol/config.yaml";
      Restart = "always";
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
}
