##############################################################################
#
# Go Binary Cache
#
# Purpose
# -------
# Cache the Go-built CLI tools (ivali, bw-tui, and any future Go
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
  goCfg = config.goBinaryCache;
  fhsCfg = config.fhsCache;

  # Space-separated store paths for `nix copy`. The actual package list is
  # provided by an inline module in flake.nix (so this module needs no
  # access to the flake outputs / specialArgs and works under nixosTest too).
  goPkgPaths = lib.concatMapStringsSep " " (p: "${p}") goCfg.packages;
  fhsPkgPaths = lib.concatMapStringsSep " " (p: "${p}") fhsCfg.packages;

  goCacheUrl = "file://${goCfg.cacheDir}";
  atticCacheUrl = "http://localhost:8080";
in
{
  options.goBinaryCache = {
    enable = lib.mkEnableOption ''
      a local binary cache for the Go-built tools (ivali, bw-tui, …)
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
      defaultText = "set per-host from flake.nix (ivali, bw-tui)";
      description = ''
        Go derivations to populate into the local binary cache. flake.nix sets
        this to the Go-built tools (ivali, bw-tui) for every host;
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

  options.fhsCache = {
    enable = lib.mkEnableOption ''
      cache FHS environment builds in the attic binary cache
      so they are restored in seconds instead of rebuilt from scratch
    '';

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = "with pkgs; [ kilocode-fhs antigravity-fhs ]";
      description = ''
        FHS environment derivations to cache. These are typically built
        with buildFHSEnv and are expensive to build from scratch.
      '';
    };

    cacheBuildClosure = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Also cache build-time dependencies. This guarantees a from-scratch
        rebuild is never required even after nix-collect-garbage.
      '';
    };
  };

  config = {
    # ═══════════════════════════════════════════════════════════════════════
    # Go Binary Cache
    # ═══════════════════════════════════════════════════════════════════════
    systemd.tmpfiles.rules = lib.mkIf goCfg.enable [
      "d ${goCfg.cacheDir} 0755 root root - -"
    ];

    nix.settings = lib.mkIf goCfg.enable {
      substituters = lib.mkAfter ([ goCacheUrl ] ++ goCfg.extraSubstituters);
      trusted-substituters = lib.mkAfter (
        if goCfg.signCache
        then goCfg.extraSubstituters
        else [ goCacheUrl ] ++ goCfg.extraSubstituters
      );
    };

    systemd.services.goBinaryCachePopulate = lib.mkIf goCfg.enable {
      description = "Populate local binary cache with Go-built tools";
      wantedBy = [ "multi-user.target" ];
      after = [ "nixos-activation.service" ];
      path = [ pkgs.nix ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        SuccessExitStatus = [ 0 ];
      };
      script = ''
        cache="${goCacheUrl}"
        echo "go-binary-cache: populating $cache"
        nix copy --to "$cache" ${goPkgPaths} || true
        ${
          lib.optionalString goCfg.cacheBuildClosure ''
            for d in ${goPkgPaths}; do
              drv="$(nix path-info --derivation "$d" 2>/dev/null || true)"
              [ -n "$drv" ] && nix copy --to "$cache" "$drv" || true
            done
          ''
        }
        echo "go-binary-cache: done"
      '';
    };

    # ═══════════════════════════════════════════════════════════════════════
    # FHS Environment Cache
    # ═══════════════════════════════════════════════════════════════════════
    systemd.services.fhsCachePopulate = lib.mkIf fhsCfg.enable {
      description = "Populate attic cache with FHS environment builds";
      wantedBy = [ "multi-user.target" ];
      after = [ "nixos-activation.service" ];
      path = [ pkgs.nix ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        SuccessExitStatus = [ 0 ];
      };
      script = ''
        echo "fhs-cache: populating attic cache with FHS builds"
        nix copy --to "${atticCacheUrl}" ${fhsPkgPaths} || true
        ${
          lib.optionalString fhsCfg.cacheBuildClosure ''
            for d in ${fhsPkgPaths}; do
              drv="$(nix path-info --derivation "$d" 2>/dev/null || true)"
              [ -n "$drv" ] && nix copy --to "${atticCacheUrl}" "$drv" || true
            done
          ''
        }
        echo "fhs-cache: done"
      '';
    };
  };
}
