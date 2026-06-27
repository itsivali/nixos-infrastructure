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
        # LocalSend transfer.
        53317
        # SSH is NOT listed here — it is restricted to tailscale0 below.
        # Opening it globally would defeat the tailscaleOnly setting in
        # ivali.ssh and expose port 22 to the public internet.
      ];
      allowedUDPPorts = [
        # Tailscale WireGuard transport. This only lets tailscaled establish
        # the tunnel; it does not make tailscale0 a trusted interface.
        41641
        # LocalSend discovery/broadcast.
        53317
      ];
      # Per-interface rules. SSH is declared here AND via ivali.ssh
      # (NixOS merges the lists). Both are explicit for documentation clarity.
      interfaces = {
        tailscale0 = {
          allowedTCPPorts = [
            # SSH — reachable only through the Tailscale tunnel.
            # Connect via prague.codlet-trench.ts.net:22
            22
          ];
          allowedUDPPorts = [ ];
        };
      };
      logRefusedConnections = true;
      logRefusedPackets = false;
    };
  };
}
