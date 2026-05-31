{ ... }:

{
  networking = {
    nftables.enable = true;

    firewall = {
      enable = true;

      # Laptop policy:
      # - inbound is explicit allow-list only
      # - outbound remains open so normal internet never depends on Tailscale
      # - established/related replies are handled by the NixOS firewall
      # - reverse path checks stay loose so VPN interfaces cannot break LAN/WAN
      allowPing = false;
      checkReversePath = "loose";
      trustedInterfaces = [ ];

      allowedTCPPorts = [
        # SSH is hardened in networking/default.nix and monitored by fail2ban.
        22

        # LocalSend transfer.
        53317
      ];

      allowedUDPPorts = [
        # Tailscale WireGuard transport. This only lets tailscaled establish
        # the tunnel; it does not make tailscale0 a trusted interface.
        41641

        # LocalSend discovery/broadcast.
        53317
      ];

      # Be explicit that no interface gets blanket access. Add per-interface
      # ports here only when a service should be reachable from that network.
      interfaces = {
        tailscale0 = {
          allowedTCPPorts = [ ];
          allowedUDPPorts = [ ];
        };
      };

      logRefusedConnections = true;
      logRefusedPackets = false;
    };
  };

}
