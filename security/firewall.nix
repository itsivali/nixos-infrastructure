{ ... }:

{
  networking = {
    nftables.enable = true;
    firewall = {
      enable = true;
      allowPing = false;
      checkReversePath = "loose";

      # LocalSend discovery and transfer. Both TCP and UDP 53317 are required
      # for laptop-to-phone discovery on the local network.
      allowedTCPPorts = [ 22 53317 ];

      # Tailscale's WireGuard transport. The interface itself is not trusted;
      # service exposure is still explicit.
      allowedUDPPorts = [ 41641 53317 ];

      logRefusedConnections = true;
      logRefusedPackets = false;
    };
  };
}
