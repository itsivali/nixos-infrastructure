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
      checkReversePath = "loose";

      trustedInterfaces = [ ];

      ##########################################################
      # Public Internet
      ##########################################################

      allowedTCPPorts = [ ];

      allowedUDPPorts =
        [
          # Tailscale
          41641

          # LocalSend
          53317
        ]
        ++ lib.optionals ts.advertiseExitNode [
          3478
        ];

      ##########################################################
      # Tailscale Only
      ##########################################################

      interfaces.tailscale0 = {

        allowedTCPPorts = [
          22
        ];

        allowedUDPPorts = [ ];
      };

      ##########################################################
      # Logging
      ##########################################################

      logRefusedConnections = true;
      logRefusedPackets = true;

      ##########################################################
      # Anti-Spoofing
      ##########################################################

      checkReversePath = "loose";
    };
  };

  ##############################################################
  # Exit Node
  ##############################################################

  boot.kernel.sysctl = lib.mkIf ts.advertiseExitNode {

    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;

    # Ignore ICMP redirects
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;

    # Never send redirects
    "net.ipv4.conf.all.send_redirects" = 0;

    # Ignore source routing
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;

    # Log suspicious packets
    "net.ipv4.conf.all.log_martians" = 1;

    # SYN flood protection
    "net.ipv4.tcp_syncookies" = 1;

    # Ignore bogus ICMP broadcasts
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;

    # Ignore bogus ICMP responses
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;

    # RFC1337 protection
    "net.ipv4.tcp_rfc1337" = 1;
  };
}
