{ lib, ... }:

{
  time.timeZone = "Africa/Nairobi";

  networking = {
    networkmanager.enable = true;
    useDHCP = lib.mkDefault true;
    nameservers = [ "1.1.1.1" "9.9.9.9" ];
  };

  services.resolved = {
    enable = true;

    fallbackDns = [
      "1.1.1.1"
      "9.9.9.9"
      "8.8.8.8"
    ];

    dnssec = "allow-downgrade";

    settings = {
      Resolve = {
        DNSOverTLS = "opportunistic";
        MulticastDNS = true;
        LLMNR = false;
      };
    };
  };

  services.openssh = {
    enable = true;
    openFirewall = false;

    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
    };
  };

  # GNOME already provides gcr-ssh-agent
  programs.ssh.startAgent = false;
}