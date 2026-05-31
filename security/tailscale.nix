{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.tailscale;
in
{
  options.ivali.tailscale = {
    enable = lib.mkEnableOption "Tailscale zero-trust networking";
    authKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional file containing a reusable or ephemeral Tailscale auth key.";
    };
    acceptDns = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow Tailscale to manage system DNS. Keep false to avoid internet loss during setup.";
    };
    acceptRoutes = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Accept tailnet subnet or exit-node routes. Keep false until explicitly configured.";
    };
    advertiseExitNode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Advertise this laptop as a tailnet exit node.";
    };
    tailnetDomain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "example.ts.net";
      description = "Tailnet DNS suffix to resolve through Tailscale MagicDNS.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      package = pkgs.tailscale;
      authKeyFile = cfg.authKeyFile;
      useRoutingFeatures = if cfg.advertiseExitNode then "both" else "client";
      openFirewall = false;
      extraUpFlags =
        [
          "--hostname=${config.networking.hostName}"
          "--accept-dns=${lib.boolToString cfg.acceptDns}"
          "--accept-routes=${lib.boolToString cfg.acceptRoutes}"
          "--ssh"
        ]
        ++ lib.optional cfg.advertiseExitNode "--advertise-exit-node";
    };

    boot.kernel.sysctl = lib.mkIf cfg.advertiseExitNode {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };

    environment.systemPackages = [ pkgs.tailscale ];

    systemd.services.tailscaled = {
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      unitConfig.StartLimitIntervalSec = 0;
      serviceConfig = {
        Restart = "always";
        RestartSec = "5s";
      };
    };

    systemd.services.tailscale-watchdog = {
      description = "Tailscale health watchdog";
      after = [ "tailscaled.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = "30s";
      };
      script = ''
        while true; do
          if ! ${pkgs.tailscale}/bin/tailscale status >/dev/null 2>&1; then
            echo "[tailscale-watchdog] restarting tailscaled"
            ${pkgs.systemd}/bin/systemctl restart tailscaled.service
          fi
          sleep 25
        done
      '';
    };

    systemd.services.tailscale-split-dns = lib.mkIf (cfg.tailnetDomain != null) {
      description = "Configure non-authoritative Tailscale split DNS";
      after = [ "tailscaled.service" "systemd-resolved.service" ];
      wants = [ "tailscaled.service" "systemd-resolved.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -eu
        if ${pkgs.iproute2}/bin/ip link show tailscale0 >/dev/null 2>&1; then
          ${pkgs.systemd}/bin/resolvectl dns tailscale0 100.100.100.100
          ${pkgs.systemd}/bin/resolvectl domain tailscale0 "~${cfg.tailnetDomain}"
          ${pkgs.systemd}/bin/resolvectl default-route tailscale0 false
        fi
      '';
    };

    systemd.timers.tailscale-split-dns = lib.mkIf (cfg.tailnetDomain != null) {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "30s";
        OnUnitActiveSec = "5m";
        Unit = "tailscale-split-dns.service";
      };
    };
  };
}
