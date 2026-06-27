{ config, lib, ... }:

let
  ts = config.ivali.tailscale;
in
{
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
      # Public Internet
      ##########################################################

      allowedTCPPorts = [ ];

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
}
