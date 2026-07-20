##############################################################################
#
# Go Binary Cache
#
# Purpose
# -------
# Cache the Go-built CLI tools (ivali, bw-tui, ivali-bot, and any future Go
# binary) in a LOCAL binary cache so that switching generations — or a build
# that was garbage-collected — restores the pre-built binary in seconds
# instead of recompiling from scratch (minutes).
#
# How it works
# ------------
# 1. A persistent directory (`cacheDir`, default /nix/var/nix/go-binary-cache,
#    living on the /nix Btrfs subvolume) is created as a `file://` binary cache.
# 2. Nix is told to consult it as a *trusted* (unsigned) substituter, so the
#    daemon will pull matching store paths from it instead of building.
# 3. A oneshot systemd service (`go-binary-cache-populate`) runs after each
#    activation and does `nix copy --to file://$cacheDir <pkg>` for every
#    package in `goBinaryCache.packages`. This realises (builds if missing)
#    and copies the package + its runtime closure into the cache. It is
#    idempotent — already-cached paths are skipped.
# 4. Optionally (default on) the build-time closure — notably the
#    `go-modules` derivation — is also cached, so even a GC'd module set is
#    restored rather than re-downloaded from the network.
#
# Combined with the hermetic `src` filter in lib/go-src.nix, this means:
#   * Editing nix/md/css/etc.            -> Go build NOT invalidated at all.
#   * Editing Go code                    -> rebuild once, then cached.
#   * After `nix-collect-garbage`        -> binary pulled from cache in seconds.
#
# Ownership
# ---------
# nix.settings.substituters / trusted-substituters, systemd.tmpfiles.rules,
# systemd.services.goBinaryCachePopulate.
#
# Usage
# -----
#   Enable and accept defaults:
#     goBinaryCache.enable = true;
#
#   Add a future Go tool (e.g. a new CLI built with buildGoModule):
#     goBinaryCache.enable = true;
#     goBinaryCache.packages = cfg.packages ++ [ flake.packages.x86_64-linux.mygo ];
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.goBinaryCache;

  # Space-separated store paths for `nix copy`. The actual package list is
  # provided by an inline module in flake.nix (so this module needs no
  # access to the flake outputs / specialArgs and works under nixosTest too).
  pkgPaths = lib.concatMapStringsSep " " (p: "${p}") cfg.packages;

  cacheUrl = "file://${cfg.cacheDir}";
in
{
  options.goBinaryCache = {
    enable = lib.mkEnableOption ''
      a local binary cache for the Go-built tools (ivali, bw-tui, ivali-bot, …)
      so they are restored in seconds instead of recompiled on every switch
    '';

    cacheDir = lib.mkOption {
      type = lib.types.str;
      default = "/nix/var/nix/go-binary-cache";
      description = ''
        Directory storing the local binary cache NARs. Must be on a persistent
        subvolume; the default lives under /nix (its own Btrfs subvolume) and
        survives both generations and garbage collection.
      '';
    };

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      defaultText = "set per-host from flake.nix (ivali, bw-tui, ivali-bot)";
      description = ''
        Go derivations to populate into the local binary cache. flake.nix sets
        this to the Go-built tools (ivali, bw-tui, ivali-bot) for every host;
        extend it here (or via an overlay) for any future Go tool so it is
        cached too.
      '';
    };

    extraSubstituters = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "https://ivali.cachix.org" ];
      description = ''
        Additional binary caches (e.g. Cachix) consulted for these packages.
        Appended after the local cache.
      '';
    };

    cacheBuildClosure = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Also cache build-time dependencies (notably the `go-modules`
        derivation). This guarantees a from-scratch rebuild is never required
        even after `nix-collect-garbage` deletes the module set.
      '';
    };

    signCache = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Sign the local cache with a Nix key and require its signature. When
        false (default) the cache is served unsigned and trusted via
        `trusted-substituters` — acceptable for a single-user laptop. Set true
        and populate `trusted-public-keys` if the cache directory is shared or
        writable by others.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # 1. Create the persistent cache directory.
    systemd.tmpfiles.rules = [
      "d ${cfg.cacheDir} 0755 root root - -"
    ];

    # 2. Register the local cache as a substituter.
    #    Unsigned local caches are trusted via `trusted-substituters` so the
    #    daemon will substitute from them without a signature. mkAfter appends
    #    to any substituters already configured (e.g. cache.nixos.org).
    nix.settings = {
      substituters = lib.mkAfter ([ cacheUrl ] ++ cfg.extraSubstituters);
      trusted-substituters = lib.mkAfter (
        if cfg.signCache
        then cfg.extraSubstituters
        else [ cacheUrl ] ++ cfg.extraSubstituters
      );
    };

    # 3. Populate the cache after each activation. The new generation's store
    #    paths are already realised by the time nixos-activation runs, so
    #    `nix copy` finds them locally and copies them into the cache.
    systemd.services.goBinaryCachePopulate = {
      description = "Populate local binary cache with Go-built tools";
      wantedBy = [ "multi-user.target" ];
      after = [ "nixos-activation.service" ];
      path = [ pkgs.nix ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # Don't block or fail the switch if caching hiccups; the build itself
        # still succeeds, we just might miss a cache entry this round.
        SuccessExitStatus = [ 0 ];
      };
      script = ''
        cache="${cacheUrl}"
        echo "go-binary-cache: populating $cache"
        # Realise (build if missing) and copy package outputs + runtime closure.
        # Idempotent: already-cached paths are skipped.
        nix copy --to "$cache" ${pkgPaths} || true
        ${
          lib.optionalString cfg.cacheBuildClosure ''
            # Also cache build-time inputs (go-modules) so a GC'd module set is
            # restored instead of re-downloaded from the network.
            for d in ${pkgPaths}; do
              drv="$(nix path-info --derivation "$d" 2>/dev/null || true)"
              [ -n "$drv" ] && nix copy --to "$cache" "$drv" || true
            done
          ''
        }
        echo "go-binary-cache: done"
      '';
    };
  };
}
