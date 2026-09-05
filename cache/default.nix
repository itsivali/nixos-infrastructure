##############################################################################
#
# Binary Cache — attic (consumer only)
#
# Purpose
# -------
# Point Nix at a binary cache so the GitOps reconciler's rebuilds are
# seconds, not 10+ minutes.
#
# NOTE: The attic *server* half was removed. The previous `atticd serve`
# invocation was invalid for the installed atticd (modern atticd uses
# `--config`) and the server had no signing key, so it never worked and
# crash-looped. Re-introduce the server half as a follow-up with a real
# signing key (SOPS-encrypted) and a correct atticd configuration file.
#
# Ownership
# ---------
# fleet.cache.*, nix.settings.substituters
#
# Dependencies
# ------------
# Requires the cache's public key (base64) for `publicKey`. Without a key
# the cache cannot be verified, so nothing is wired into Nix (fail-safe).
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
  };

  config = lib.mkIf (cfg.enable && cfg.publicKey != "") {
    # Fail-safe: only wire the cache into Nix when a verifiable public key is
    # actually configured. An empty key would produce a corrupt
    # trusted-public-keys entry ("cache.foo.ts.net-1:" with no key material),
    # which makes every uncached `nix` fetch hard-fail with "key is corrupt".
    # A cache without a signing key cannot be verified, so wiring it in would
    # be worse than not wiring it at all.

    # Prepend the user cache ahead of cache.nixos.org.
    nix.settings.substituters = lib.mkBefore [ cfg.url ];
    nix.settings.trusted-public-keys = lib.mkBefore [ trustedKey ];

    environment.systemPackages = [ pkgs.attic-client ];
  };
}
