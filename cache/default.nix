##############################################################################
#
# Binary Cache — attic (consumer + optional server)
#
# Purpose
# -------
# Point Nix at a binary cache so the GitOps reconciler's rebuilds are
# seconds, not 10+ minutes. Two parts:
#   * consumer: this host *uses* a cache at `url` (e.g. a Tailscale
#     peer running the server half, or any attic instance).
#   * server:   optionally run an attic server here so peers / VMs can
#     pull this host's store. On a single laptop the consumer side is
#     the useful one (point it at a machine that builds for you).
#
# Ownership
# ---------
# fleet.cache.*, nix.settings.substituters, optional attic systemd unit
#
# Dependencies
# ------------
# Requires the cache's public key (base64) for `publicKey`.
# The server half needs the attic package (MIT) and an open port on the
# Tailscale interface.
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.fleet.cache;

  # "https://cache.foo.ts.net" -> "cache.foo.ts.net"
  host = lib.replaceStrings [ "https://" "http://" "/" ] [ "" "" "" ] cfg.url;
  trustedKey = "${host}-1:${cfg.publicKey}";
in
{
  options.fleet.cache = {
    enable = lib.mkEnableOption "binary cache (attic) consumer";

    url = lib.mkOption {
      type = lib.types.str;
      default = "https://cache.prague.ts.net";
      example = "https://cache.prague.ts.net";
      description = "Binary cache base URL this host pulls from.";
    };

    publicKey = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "7F2...base64...";
      description = "attic public key (base64) of the cache at `url`.";
    };

    server = {
      enable = lib.mkEnableOption "run an attic server on this host";

      listen = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0:8080";
        description = "Address:port the attic server listens on.";
      };

      storeDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/attic";
        description = "Directory attic serves the store from.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Prepend the user cache ahead of cache.nixos.org.
    nix.settings.substituters = lib.mkBefore [ cfg.url ];
    nix.settings.trusted-public-keys = lib.mkBefore [ trustedKey ];

    environment.systemPackages = [ pkgs.attic-client ];

    systemd.services.attic-server = lib.mkIf cfg.server.enable {
      description = "attic binary cache server";
      after = [ "network-online.target" ];
      requires = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        DynamicUser = true;
        StateDirectory = "attic";
        ExecStart = "${pkgs.attic-server}/bin/attic serve --listen ${cfg.server.listen} --store ${cfg.server.storeDir}";
        Restart = "on-failure";
      };
    };
  };
}
