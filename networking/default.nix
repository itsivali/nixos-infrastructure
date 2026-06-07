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

  programs.ssh.knownHosts.gitlab-com = {
    hostNames = [ "gitlab.com" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfuCHKVTjquxvt6CM6tdG4SLp1Btn/nOeHHE5UOzRdf";
  };

  # GNOME already provides gcr-ssh-agent
  programs.ssh.startAgent = false;
}
