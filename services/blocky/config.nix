##############################################################################
#
# Services Blocky — DNS Proxy & Ad-Blocker
#
# Purpose
# -------
# Privacy-focused DNS proxy with ad/tracker/malware blocking for the
# tailnet. Serves DNS on port 53 and Prometheus metrics on port 4000.
#
# Ownership
# ---------
# services/blocky
#
# Does NOT Own
# ------------
# - Firewall policy (security/firewall.nix) — only the blocky ports on
#   tailscale0 are opened here (mirrors desktop/remote-desktop/grd.nix).
# - AppArmor profile (security/apparmor.nix) — the blocky profile is
#   defined there and attached here.
# - Prometheus scrape registration (observability/prometheus.nix) — the
#   blocky job is owned by the observability module.
#
# Security model
# --------------
# * Blocky binds all interfaces (nftables) but the firewall only opens
#   port 53 on `tailscale0` — the same pattern used for SSH and RDP. The
#   service stays unreachable from the public internet.
# * Runs with the nixpkgs hardened service config (DynamicUser,
#   ProtectSystem=strict, NoNewPrivileges, SystemCallFilter) plus an
#   AppArmor profile.
#
# Usage
# -----
#   ivali.services.blocky = {
#     enable = true;
#     upstreams = [ "1.1.1.1" "9.9.9.9" ];
#   };
#
##############################################################################

{ config, lib, ... }:

let
  cfg = config.ivali.services.blocky;
in
{
  options.ivali.services.blocky = {
    enable = lib.mkEnableOption "Blocky DNS proxy and ad-blocker";

    port = lib.mkOption {
      type = lib.types.port;
      default = 53;
      description = "UDP/TCP port Blocky listens on for DNS queries.";
    };

    metricsPort = lib.mkOption {
      type = lib.types.port;
      default = 4000;
      description = "HTTP port for Blocky's Prometheus metrics endpoint.";
    };

    upstreams = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "1.1.1.1" "9.9.9.9" ];
      example = [ "1.1.1.1" "9.9.9.9" ];
      description = ''
        Upstream DNS resolvers Blocky forwards queries to.
        Supports plain DNS, DoH (https://) and DoT (tcp-tls://).
      '';
    };

    blocklists = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
        "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn/hosts"
      ];
      description = ''
        Blocklist URLs. Each URL is downloaded at Blocky startup and
        cached in memory. See https://filterlists.com for candidates.
      '';
    };

    tailscaleOnly = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Restrict the DNS port to the Tailscale interface. When disabled,
        the port is opened on all interfaces — not recommended.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.blocky = {
      enable = true;
      settings = {
        port = cfg.port;
        httpPort = cfg.metricsPort;
        logLevel = "warn";

        upstream = {
          default = cfg.upstreams;
        };

        blocking = {
          denylists.ads = cfg.blocklists;
          clientGroupsBlock.default = [ "ads" ];
        };

        prometheus.enable = true;
      };
    };

    # ── Firewall: DNS on Tailscale only (mirrors ssh/daemon.nix and RDP) ──
    networking.firewall.interfaces.tailscale0.allowedTCPPorts =
      lib.mkIf cfg.tailscaleOnly [ cfg.port ];
    networking.firewall.interfaces.tailscale0.allowedUDPPorts =
      lib.mkIf cfg.tailscaleOnly [ cfg.port ];
    networking.firewall.allowedTCPPorts =
      lib.mkIf (!cfg.tailscaleOnly) [ cfg.port ];
    networking.firewall.allowedUDPPorts =
      lib.mkIf (!cfg.tailscaleOnly) [ cfg.port ];

    # ── AppArmor confinement ──────────────────────────────────────────────
    systemd.services.blocky.serviceConfig.AppArmorProfile =
      lib.mkIf (config.security.apparmor.enable or false) "blocky";
  };
}
