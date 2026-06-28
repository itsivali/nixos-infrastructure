##############################################################################
#
# Network Manager & DNS
#
# Purpose
# -------
# NetworkManager, systemd-resolved, and DNS configuration.
#
# Ownership
# ---------
# networking.networkmanager, networking.useDHCP,
# networking.nameservers, services.resolved
#
# Does NOT Own
# ------------
# - Time zone (networking/time.nix)
# - SSH server (networking/ssh-server.nix)
# - Email relay (networking/msmtp/)
#
##############################################################################

{ lib, ... }:

{
  networking = {
    networkmanager.enable = true;
    useDHCP = lib.mkDefault true;
    nameservers = [ "1.1.1.1" "9.9.9.9" ];
  };

  services.resolved = {
    enable = true;

    settings = {
      Resolve = {
        FallbackDNS = [
          "1.1.1.1"
          "9.9.9.9"
          "8.8.8.8"
        ];

        DNSSEC = "allow-downgrade";
        DNSOverTLS = "opportunistic";
        MulticastDNS = true;
        LLMNR = false;
      };
    };
  };
}
