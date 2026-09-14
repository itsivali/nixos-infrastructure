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

{ config, lib, pkgs, ... }:

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

  ############################################################
  # Wi-Fi self-healing — purge stale connection profiles
  ############################################################
  #
  # NetworkManager persists every network it has ever joined as a keyfile
  # under /etc/NetworkManager/system-connections/. When a profile's SSID is
  # no longer in range, NM keeps trying it and can appear "locked" to a
  # network from an earlier installation. This service purges profiles whose
  # SSID is not currently visible — no SSID is ever hard-coded here, so the
  # laptop remains free to join home / hotspot / office / public Wi-Fi.
  #
  # Runs on a timer, is idempotent, and never blocks networking.
  ############################################################

  systemd.services.nm-stale-profiles = {
    description = "Purge stale NetworkManager Wi-Fi profiles";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeShellScriptBin "nm-purge-stale-profiles" ''
        set -euo pipefail

        CONN_DIR="/etc/NetworkManager/system-connections"
        if [[ ! -d "$CONN_DIR" ]]; then
          exit 0
        fi

        # SSIDs currently visible on any Wi-Fi interface
        VISIBLE="$(nmcli -t -f SSID device wifi list --rescan yes 2>/dev/null || true)"

        purged=0
        for f in "$CONN_DIR"/*.nmconnection; do
          [[ -e "$f" ]] || continue
          # Skip non-Wi-Fi profiles (eth, vpn, etc.)
          if ! grep -q '^802-11-wireless' "$f" 2>/dev/null; then
            continue
          fi
          ssid="$(grep -m1 '^connection.id=' "$f" 2>/dev/null | cut -d= -f2-)"
          [[ -n "$ssid" ]] || continue
          if ! printf '%s\n' "$VISIBLE" | grep -qxF "$ssid"; then
            echo "Purging stale profile: ''${ssid}"
            rm -f "$f"
            purged=$((purged + 1))
          fi
        done

        echo "Stale profile purge complete (''${purged} removed)"
      ''}/bin/nm-purge-stale-profiles";
    };
  };

  systemd.timers.nm-stale-profiles = {
    description = "Purge stale NetworkManager Wi-Fi profiles";
    wantedBy = [ "timers.target" ];

    timerConfig = {
      OnBootSec = "2m";
      OnUnitActiveSec = "10m";
      Persistent = true;
    };
  };
}
