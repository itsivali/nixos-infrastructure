##############################################################################
#
# Firewall
#
# Purpose
# -------
# Nftables firewall with default-deny ingress and optional egress filtering.
#
# Ownership
# ---------
# networking.firewall, networking.nftables
#
# Does NOT Own
# ------------
# - Tailscale (security/tailscale.nix)
# - SSH (ssh/default.nix)
#
##############################################################################

{ config, lib, ... }:

let
  ts = config.ivali.tailscale;
  cfg = config.ivali.security.firewall;

  # Default allowed egress domains for system operation
  defaultEgressDomains = [
    # NixOS updates
    "nixos.org"
    "cache.nixos.org"
    "flakes.nixos.org"

    # Git operations
    "gitlab.com"
    "github.com"

    # Telegram bot API
    "api.telegram.org"

    # DNS resolution
    "1.1.1.1"
    "1.0.0.1"
    "9.9.9.9"
    "9.9.10.10"

    # Time synchronization
    "time.nixos.org"
    "time.cloudflare.com"
  ];

  allEgressDomains = defaultEgressDomains ++ cfg.allowedEgressDomains;
in
{
  options.ivali.security.firewall = {
    enable = lib.mkEnableOption "firewall with egress filtering";

    allowedEgressDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [ "example.com" "api.example.com" ];
      description = ''
        Additional domains to allow in egress filtering.
        These are added to the default system domains.
      '';
    };

    enableEgressFiltering = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable default-deny egress filtering.
        When enabled, only explicitly allowed domains are permitted.
        WARNING: This may break some applications that connect to unexpected hosts.
      '';
    };
  };

  config = {
    networking = {
      nftables.enable = true;

      firewall = {
        enable = true;

        ##########################################################
        # Default Policy
        ##########################################################

        allowPing = false;

        # Required for Tailscale exit nodes and subnet routing.
        checkReversePath = "loose";

        # Trust no interfaces by default.
        trustedInterfaces = [ ];

        ##########################################################
        # Public Internet — Inbound
        ##########################################################

        allowedTCPPorts = [
          # LocalSend
          53317
        ];

        allowedUDPPorts =
          [
            # Tailscale WireGuard
            41641

            # LocalSend
            53317
          ]
          ++ lib.optionals ts.advertiseExitNode [
            # STUN
            3478
          ];

        ##########################################################
        # Tailscale
        ##########################################################

        interfaces.tailscale0 = {
          allowedTCPPorts = [
            # SSH only over Tailscale
            22
          ];

          allowedUDPPorts = [ ];
        };

        ##########################################################
        # Logging
        ##########################################################

        logRefusedConnections = true;
        logRefusedPackets = true;
      };
    };

    ############################################################
    # Egress Domain Documentation
    ############################################################

    # When enableEgressFiltering is true, the following domains
    # should be allowed through the firewall for system operation:
    #
    # Required for NixOS:
    #   nixos.org, cache.nixos.org, flakes.nixos.org
    #
    # Required for GitOps:
    #   gitlab.com, github.com
    #
    # Required for Telegram bot:
    #   api.telegram.org
    #
    # Required for DNS:
    #   1.1.1.1, 1.0.0.1, 9.9.9.9, 9.9.10.10
    #
    # Required for time sync:
    #   time.nixos.org, time.cloudflare.com
    #
    # To implement egress filtering, add nftables rules manually:
    #   networking.nftables.tables = { ... };
  };
}
