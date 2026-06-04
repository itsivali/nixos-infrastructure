{ config, lib, pkgs, ... }:

let
cfg = config.ivali.tailscale;
in
{
options.ivali.tailscale = {
enable = lib.mkEnableOption "Tailscale zero-trust networking";

```
authKeyFile = lib.mkOption {
  type = lib.types.nullOr lib.types.str;
  default = null;
  description = ''
    File containing a reusable Tailscale auth key.
    Typically provided through sops-nix.
  '';
};

tag = lib.mkOption {
  type = lib.types.str;
  default = "tag:admin";
  example = "tag:user";
  description = ''
    Tailscale ACL tag to advertise.
  '';
};

acceptDns = lib.mkOption {
  type = lib.types.bool;
  default = false;
  description = ''
    Allow Tailscale to manage DNS.
    Disabled by default to avoid accidental internet disruptions.
  '';
};

acceptRoutes = lib.mkOption {
  type = lib.types.bool;
  default = false;
  description = ''
    Accept routes advertised by other nodes.
  '';
};

advertiseExitNode = lib.mkOption {
  type = lib.types.bool;
  default = false;
  description = ''
    Advertise this machine as an exit node.
  '';
};

tailnetDomain = lib.mkOption {
  type = lib.types.nullOr lib.types.str;
  default = null;
  example = "codlet-trench.ts.net";
  description = ''
    Tailnet DNS suffix for split DNS.
  '';
};
```

};

config = lib.mkIf cfg.enable {

```
#########################################################
# Tailscale
#########################################################

services.tailscale =
  {
    enable = true;

    package = pkgs.tailscale;

    useRoutingFeatures =
      if cfg.advertiseExitNode
      then "both"
      else "client";

    openFirewall = false;

    extraUpFlags =
      [
        "--hostname=${config.networking.hostName}"
        "--advertise-tags=${cfg.tag}"
        "--accept-dns=${lib.boolToString cfg.acceptDns}"
        "--accept-routes=${lib.boolToString cfg.acceptRoutes}"
        "--ssh"
      ]
      ++ lib.optional cfg.advertiseExitNode
        "--advertise-exit-node";
  }
  // lib.optionalAttrs (cfg.authKeyFile != null) {
    authKeyFile = cfg.authKeyFile;
  };

#########################################################
# Exit Node Routing
#########################################################

boot.kernel.sysctl =
  lib.mkIf cfg.advertiseExitNode {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

#########################################################
# Packages
#########################################################

environment.systemPackages = [
  pkgs.tailscale
];

#########################################################
# tailscaled resilience
#########################################################

systemd.services.tailscaled = {
  wants = [ "network-online.target" ];

  after = [ "network-online.target" ];

  unitConfig.StartLimitIntervalSec = 0;

  serviceConfig = {
    Restart = "always";
    RestartSec = "5s";
  };
};

#########################################################
# Split DNS
#########################################################

systemd.services.tailscale-split-dns =
  lib.mkIf (cfg.tailnetDomain != null) {

    description = "Configure Tailscale split DNS";

    after = [
      "tailscaled.service"
      "systemd-resolved.service"
    ];

    wants = [
      "tailscaled.service"
      "systemd-resolved.service"
    ];

    wantedBy = [
      "multi-user.target"
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      set -euo pipefail

      if ${pkgs.iproute2}/bin/ip link show tailscale0 >/dev/null 2>&1; then
        ${pkgs.systemd}/bin/resolvectl dns tailscale0 100.100.100.100

        ${pkgs.systemd}/bin/resolvectl domain tailscale0 \
          "~${cfg.tailnetDomain}"

        ${pkgs.systemd}/bin/resolvectl default-route tailscale0 false
      fi
    '';
  };

systemd.timers.tailscale-split-dns =
  lib.mkIf (cfg.tailnetDomain != null) {

    wantedBy = [ "timers.target" ];

    timerConfig = {
      OnBootSec = "30s";
      OnUnitActiveSec = "5m";
      Unit = "tailscale-split-dns.service";
    };
  };
```

};
}
