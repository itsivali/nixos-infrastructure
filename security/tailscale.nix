{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.tailscale;

  effectiveTags =
    cfg.tags
    ++ lib.optional (
      cfg.advertiseExitNode &&
      !(builtins.elem "tag:exit-node" cfg.tags)
    ) "tag:exit-node";

  advertisedTags = lib.concatStringsSep "," effectiveTags;

in {
  options.ivali.tailscale = {
    enable = lib.mkEnableOption "Tailscale";

    authKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a reusable Tailscale auth key.";
    };

    tags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "tag:user" ];
      example = [
        "tag:admin"
        "tag:infra"
      ];
      description = "ACL tags assigned to this node.";
    };

    acceptDns = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow Tailscale to manage DNS.";
    };

    acceptRoutes = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Accept routes advertised by other Tailscale nodes.";
    };

    advertiseExitNode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Advertise this machine as an exit node.";
    };

    exitNode = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "prague";
      description = "Use another Tailscale device as an exit node.";
    };

    exitNodeAllowLanAccess = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Keep access to the local LAN while using an exit node.";
    };

    useRoutingFeatures = lib.mkOption {
      type = lib.types.enum [
        "none"
        "client"
        "server"
        "both"
      ];

      default =
        if config.ivali.tailscale.advertiseExitNode
        then "both"
        else "client";

      description = "Routing features enabled by tailscaled.";
    };

    tailnetDomain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "example.ts.net";
      description = "Tailnet split DNS domain.";
    };
  };

  config = lib.mkIf cfg.enable {

    services.tailscale =
      {
        enable = true;

        package = pkgs.tailscale;

        openFirewall = false;

        useRoutingFeatures = cfg.useRoutingFeatures;

        extraUpFlags =
          [
            "--hostname=${config.networking.hostName}"
            "--advertise-tags=${advertisedTags}"
            "--accept-dns=${lib.boolToString cfg.acceptDns}"
            "--accept-routes=${lib.boolToString cfg.acceptRoutes}"
            "--ssh"
          ]
          ++ lib.optional cfg.advertiseExitNode
            "--advertise-exit-node"
          ++ lib.optional (cfg.exitNode != null)
            "--exit-node=${cfg.exitNode}"
          ++ lib.optional (
            cfg.exitNode != null &&
            cfg.exitNodeAllowLanAccess
          )
            "--exit-node-allow-lan-access";
      }
      // lib.optionalAttrs (cfg.authKeyFile != null) {
        authKeyFile = cfg.authKeyFile;
      };

    boot.kernel.sysctl = lib.mkIf cfg.advertiseExitNode {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };

    environment.systemPackages = [
      pkgs.tailscale
    ];

    systemd.services.tailscaled = {
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      unitConfig.StartLimitIntervalSec = 0;

      serviceConfig = {
        Restart = "always";
        RestartSec = "5s";

        StateDirectory = "tailscale";
      };
    };

    systemd.services.tailscale-split-dns =
      lib.mkIf (cfg.tailnetDomain != null) {
        description = "Configure Tailscale split DNS";

        after = [
          "tailscaled.service"
          "systemd-resolved.service"
        ];

        wants = [
          "tailscaled.service"
          "systemd-resolved.service"
        ];

        wantedBy = [
          "multi-user.target"
        ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };

        script = ''
          set -euo pipefail

          if ${pkgs.iproute2}/bin/ip link show tailscale0 >/dev/null 2>&1; then
            ${pkgs.systemd}/bin/resolvectl dns tailscale0 100.100.100.100
            ${pkgs.systemd}/bin/resolvectl domain tailscale0 "~${cfg.tailnetDomain}"
            ${pkgs.systemd}/bin/resolvectl default-route tailscale0 false
          fi
        '';
      };

    systemd.timers.tailscale-split-dns =
      lib.mkIf (cfg.tailnetDomain != null) {
        wantedBy = [ "timers.target" ];

        timerConfig = {
          OnBootSec = "30s";
          OnUnitActiveSec = "5m";
          Unit = "tailscale-split-dns.service";
        };
      };
  };
}
