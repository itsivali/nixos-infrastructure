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
# - SSH server (ssh/daemon.nix)
# - Email relay (services/msmtp/)
#
##############################################################################

{ ... }:

{
  networking = {
    networkmanager = {
      enable = true;

      # Let NetworkManager fully manage interfaces. useDHCP only applies to
      # interfaces that NetworkManager does not own, so it is not set here —
      # declaring it would be redundant and potentially ambiguous.
      dns = "systemd-resolved";

      wifi = {
        # Disable Wi-Fi power saving. The rtw88_8821ce chipset on the Lenovo
        # AMD laptops drops connections when power saving is enabled, which
        # breaks "always connected to wifi". Disabling it tells NetworkManager
        # to write wifi.powersave=2 (NX_DISABLE).
        powersave = false;
      };
    };

    # Global fallback resolvers used when no per-link DNS is provided by DHCP.
    # Per-link DHCP-provided DNS remains the primary resolver for each link
    # (see services.resolved below); these nameservers only serve as the
    # system-wide fallback via resolved's Resolve.DNS default.
    nameservers = [ "1.1.1.1" "9.9.9.9" ];
  };

  services.resolved = {
    enable = true;

    settings = {
      Resolve = {
        # System-wide fallback DNS (used when no per-link DNS is supplied by
        # DHCP). Per-link DHCP-provided DNS stays primary for each interface,
        # which keeps captive portals and local DNS working correctly.
        DNS = [
          "1.1.1.1"
          "9.9.9.9"
        ];

        FallbackDNS = [
          "1.1.1.1"
          "9.9.9.9"
          "8.8.8.8"
        ];

        # Opportunistic DNS-over-TLS: upgrades to TLS when the upstream
        # resolver supports it, falls back to plaintext otherwise. This keeps
        # connectivity on captive-portal / local DHCP resolvers while still
        # encrypting when possible.
        DNSSEC = "allow-downgrade";
        DNSOverTLS = "opportunistic";

        # mDNS on for local network discovery (GNOME Nearby/streaming),
        # LLMNR off (mDNS covers the same use case more securely).
        MulticastDNS = true;
        LLMNR = false;
      };
    };
  };
}
