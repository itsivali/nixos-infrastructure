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
      example = [ "tag:admin" "tag:infra" ];
      description = ''
        Tailscale ACL tags to advertise on this node.
        When advertiseExitNode is true, tag:exit-node is automatically
        appended unless already present.
      '';
    };

    acceptDns = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Allow Tailscale to manage DNS.
        Disabled by default to avoid accidental internet disruptions.
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
  };

  config = lib.mkIf cfg.enable {

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

            ${pkgs.systemd}/bin/resolvectl domain tailscale0 \
              "~${cfg.tailnetDomain}"

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

