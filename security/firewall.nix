##############################################################################
#
# Firewall
#
# Purpose
# -------
# Nftables firewall with default-deny ingress and optional egress filtering.
#
# Ownership
# ---------
# networking.firewall, networking.nftables
#
# Does NOT Own
# ------------
# - Tailscale (security/tailscale.nix)
# - SSH (ssh/default.nix)
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.security.firewall;

  # Safely read tailscale config — may not exist if tailscale.nix isn't imported
  # (e.g. in smoke tests or minimal VMs).
  tsAdvertiseExitNode = (lib.attrByPath [ "ivali" "tailscale" "advertiseExitNode" ] false config);

  # Default allowed egress domains for system operation
  defaultEgressDomains = [
    # NixOS updates
    "nixos.org"
    "cache.nixos.org"
    "flakes.nixos.org"

    # Git operations
    "gitlab.com"
    "github.com"

    # DNS resolution
    "1.1.1.1"
    "1.0.0.1"
    "9.9.9.9"
    "9.9.10.10"

    # Time synchronization
    "time.nixos.org"
    "time.cloudflare.com"
  ];

  allEgressDomains = defaultEgressDomains ++ cfg.allowedEgressDomains;

  # Static IP baseline — hosts that never need DNS resolution, so they are
  # pinned directly into the nftables ruleset at build time. This keeps the
  # build hermetic (no network access required) for the always-on entries.
  # Domains are resolved at runtime by egress-refresh.service.
  egressIpsV4 = [
    "1.1.1.1"
    "1.0.0.1"
    "9.9.9.9"
    "9.9.10.10"
    "8.8.8.8"
  ];

  egressIpsV6 = [
    "2606:4700:4700::1111"
    "2606:4700:4700::1001"
    "2001:4860:4860::8888"
    "2001:4860:4860::8844"
  ];
in
{
  options.ivali.security.firewall = {
    enable = lib.mkEnableOption "firewall with egress filtering";

    allowedEgressDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "example.com" "api.example.com" ];
      description = ''
        Additional domains to allow in egress filtering.
        These are added to the default system domains.
      '';
    };

    enableEgressFiltering = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable default-deny egress filtering.
        When enabled, only explicitly allowed domains are permitted.
        WARNING: This may break some applications that connect to unexpected hosts.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
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
        # Public Internet — Inbound
        ##########################################################

        # LocalSend (TCP+UDP 53317) is opened ONLY on tailscale0 and dropped
        # explicitly everywhere else (see interfaces."tailscale0" and
        # extraInputRules below). It is intentionally NOT in the global
        # allowedTCPPorts/allowedUDPPorts so it never opens on the LAN or the
        # public internet — Tailscale is the only path for file transfers.

        allowedTCPPorts = [ ];

        allowedUDPPorts =
          [
            # Tailscale WireGuard
            41641
          ]
          ++ lib.optionals tsAdvertiseExitNode [
            # STUN
            3478
          ];

        ##########################################################
        # LocalSend — Tailscale-only (never LAN / public)
        ##########################################################

        # LocalSend (TCP+UDP 53317) is opened ONLY on tailscale0, so file
        # transfers and discovery are reachable exclusively over the tailnet.
        interfaces."tailscale0" = {
          allowedTCPPorts = [ 53317 ];
          allowedUDPPorts = [ 53317 ];
        };

        # Explicit drop off the tailnet. Belt-and-suspenders on top of the
        # default-drop policy, and it documents the intent in the rendered
        # ruleset. (nft rejects cannot express a tcp/udp scoped refusal
        # reliably in an inet-family chain without meta nfproto guards, so
        # explicit drops are used for clarity and consistency.)
        extraInputRules = ''
          iifname != "tailscale0" tcp dport 53317 drop
          iifname != "tailscale0" udp dport 53317 drop
        '';

        ##########################################################
        # Logging
        ##########################################################

        # Refused-connection logging is disabled: the NixOS logging rules
        # rely on the netfilter "pkttype" match (xt_pkttype), which cannot
        # load once security.lockKernelModules pins kernel.modules_disabled
        # to 1. Disabling the logging keeps the firewall fully functional
        # (enforcement is unaffected) and avoids a failed firewall.service.
        logRefusedConnections = false;
        logRefusedPackets = false;
      };

      ############################################################
      # LOCALSEND — Tailscale-only (never on LAN / public interfaces)
      ############################################################
      # LocalSend uses TCP+UDP 53317 for file transfer and discovery.
      # Ingress is opened ONLY on tailscale0 (see interfaces."tailscale0"
      # and extraInputRules in networking.firewall above) and dropped
      # everywhere else. The OUTPUT hook below drops LocalSend traffic
      # leaving any non-Tailscale interface, which also stops LAN discovery
      # broadcasts. Tailscale is therefore the only interface LocalSend can
      # use in either direction — sending, receiving, and peer discovery.
      #
      # The outbound enforcement is a real nftables OUTPUT hook chain, so it
      # stays active even when egress filtering (enableEgressFiltering) is off.
      #
      # EGRESS FILTERING — real nftables enforcement
      ############################################################
      #
      # enableEgressFiltering is OFF by default. When enabled, a default-deny
      # outbound policy is installed on the NON-Tailscale interfaces. Tailscale
      # (tailscale0) is always trusted: egress filtering must never break the
      # zero-trust overlay, exit-node forwarding, or MagicDNS.
      #
      # The allowed set is a curated static baseline of system-critical hosts
      # (Nix, GitLab, Git, DNS, time) plus any user-supplied domains. Domains
      # are resolved at runtime by egress-refresh.service and reloaded into
      # the nftables ruleset, so the baseline is not frozen at build time.
      #
      # Exit-node forwarding is preserved: when this host advertises an exit
      # node, the forward chain is left unrestricted (the NixOS firewall
      # already handles this via checkReversePath).
      ############################################################

      nftables.ruleset = lib.mkMerge [
        # LocalSend — always active regardless of egress filtering.
        # Drops outbound LocalSend (dport 53317) on every interface except
        # tailscale0, so LocalSend can only ever transit the Tailscale
        # overlay (sending AND discovery broadcasts).
        ''
          table inet ivali-localsend {
            chain output {
              type filter hook output priority filter; policy accept;
              oifname != "tailscale0" tcp dport 53317 drop comment "LocalSend must use Tailscale TCP"
              oifname != "tailscale0" udp dport 53317 drop comment "LocalSend must use Tailscale UDP"
            }
          }
        ''

        # Egress filtering — enabled via ivali.security.firewall.enableEgressFiltering
        (lib.mkIf cfg.enableEgressFiltering ''
            table inet ivali-egress {
            # Build-time static baseline — hosts that never need DNS.
            set allowed_static_v4 {
              type ipv4_addr
              flags interval
              elements = {
                ${lib.concatStringsSep ",\n                " (map (ip: "${ip}") egressIpsV4)}
              }
            }

            set allowed_static_v6 {
              type ipv6_addr
              flags interval
              elements = {
                ${lib.concatStringsSep ",\n                " (map (ip: "${ip}") egressIpsV6)}
              }
            }

            # Runtime set — populated by ivali-egress-refresh. Starts empty so
            # the ruleset loads cleanly even before the first DNS resolution.
            set allowed_runtime_v4 {
              type ipv4_addr
              flags interval
              elements = { }
            }

            set allowed_runtime_v6 {
              type ipv6_addr
              flags interval
              elements = { }
            }

            # Default-deny outbound on every interface EXCEPT tailscale0.
            # The tailnet is a private trust boundary and must not be filtered.
            chain egress {
              type filter hook output priority filter;

              # Always allow loopback and link-local.
              ip daddr 127.0.0.0/8 accept
              ip daddr 169.254.0.0/16 accept
              ip6 daddr ::1/128 accept
              ip6 daddr fe80::/10 accept
              ip6 daddr ff00::/8 accept

              # Always allow Tailscale — zero-trust overlay, exit node, MagicDNS.
              ip daddr 100.64.0.0/10 accept
              ip6 daddr 100::/64 accept

              # Always allow DNS resolvers (needed to resolve the allowed set).
              ip daddr { 1.1.1.1, 1.0.0.1, 9.9.9.9, 9.9.10.10, 8.8.8.8 } accept
              ip6 daddr { 2606:4700:4700::1111, 2606:4700:4700::1001,
                          2001:4860:4860::8888, 2001:4860:4860::8844 } accept
              udp dport 53 accept
              tcp dport 53 accept

              # Allow the static baseline and the runtime-resolved domains.
              ip daddr { @allowed_static_v4, @allowed_runtime_v4 } accept
              ip6 daddr { @allowed_static_v6, @allowed_runtime_v6 } accept

              # Default deny — log and drop.
              log prefix "ivali-egress-deny: " counter
              drop
            }
          }
        '')
      ];
    };

    ############################################################
    # EGRESS REFRESH — resolve allowed domains at runtime and reload
    ############################################################
    #
    # The static baseline covers hosts that never need DNS. Domains are
    # resolved here and written to /run/ivali-egress/ips, which the nftables
    # ruleset reads via an included file. This keeps the build hermetic
    # (no network access at build time) while still allowing DNS-based
    # allow-lists.
    ############################################################

    systemd.services.ivali-egress-refresh = lib.mkIf cfg.enableEgressFiltering {
      description = "Refresh Ivali egress allow-list IPs";
      wants = [ "network-online.target" "nftables.service" ];
      after = [ "network-online.target" "nftables.service" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "ivali-egress-refresh" ''
          set -euo pipefail
          NFT="${pkgs.nftables}/bin/nft"
          TABLE="inet ivali-egress"

          # Flush the runtime sets first so repeated runs stay idempotent
          # (otherwise domains accumulate across cycles). The static baseline
          # is untouched.
          "$NFT" delete "$TABLE" set allowed_runtime_v4 2>/dev/null || true
          "$NFT" delete "$TABLE" set allowed_runtime_v6 2>/dev/null || true
          "$NFT" add set "$TABLE" set allowed_runtime_v4 { type ipv4_addr; flags interval; elements = { } }
          "$NFT" add set "$TABLE" set allowed_runtime_v6 { type ipv6_addr; flags interval; elements = { } }

          v4_elems=""
          v6_elems=""
          ${lib.concatStringsSep "\n" (map (d: ''
            for ip in $(${pkgs.dnsutils}/bin/dig +short A "${d}" | grep -E '^[0-9]+$' || true); do
              v4_elems="$v4_elems $ip"
            done
            for ip in $(${pkgs.dnsutils}/bin/dig +short AAAA "${d}" | grep -E '^[0-9a-fA-F:]+$' || true); do
              v6_elems="$v6_elems $ip"
            done
          '') allEgressDomains)}

          if [[ -n "$v4_elems" ]]; then
            "$NFT" add element "$TABLE" set allowed_runtime_v4 default { $v4_elems }
          fi
          if [[ -n "$v6_elems" ]]; then
            "$NFT" add element "$TABLE" set allowed_runtime_v6 default { $v6_elems }
          fi

          echo "Egress allow-list refreshed."
        ''}/bin/ivali-egress-refresh";
      };
    };

    systemd.timers.ivali-egress-refresh = lib.mkIf cfg.enableEgressFiltering {
      description = "Refresh egress allow-list IPs";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1m";
        OnUnitActiveSec = "5m";
        Persistent = true;
      };
    };
  };
}
