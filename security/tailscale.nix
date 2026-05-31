{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.tailscale;
in
{
  options.ivali.tailscale = {
    enable = lib.mkEnableOption "Tailscale zero-trust networking";
    tailnetDomain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "example.ts.net";
      description = "Tailnet DNS suffix to resolve through Tailscale MagicDNS.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      useRoutingFeatures = "client";
      openFirewall = false;
      extraUpFlags = [
        "--accept-dns=false"
        "--accept-routes=false"
        "--ssh"
      ];
    };

    environment.systemPackages = [ pkgs.tailscale ];

    systemd.services.tailscale-split-dns = lib.mkIf (cfg.tailnetDomain != null) {
      description = "Configure non-authoritative Tailscale split DNS";
      after = [ "tailscaled.service" "systemd-resolved.service" ];
      wants = [ "tailscaled.service" "systemd-resolved.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -eu
        if ${pkgs.iproute2}/bin/ip link show tailscale0 >/dev/null 2>&1; then
          ${pkgs.systemd}/bin/resolvectl dns tailscale0 100.100.100.100
          ${pkgs.systemd}/bin/resolvectl domain tailscale0 "~${cfg.tailnetDomain}"
          ${pkgs.systemd}/bin/resolvectl default-route tailscale0 false
        fi
      '';
    };

    systemd.timers.tailscale-split-dns = lib.mkIf (cfg.tailnetDomain != null) {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "30s";
        OnUnitActiveSec = "5m";
        Unit = "tailscale-split-dns.service";
      };
    };
  };
}
