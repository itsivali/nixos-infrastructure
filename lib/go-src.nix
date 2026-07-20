##############################################################################
#
# Hermetic Go source filter
#
# Purpose
# -------
# Build a clean source tree that contains ONLY the Go toolchain inputs
# (Go source, go.mod, go.sum, go.work) and nothing else. This makes the
# buildGoModule `src` hash stable so that editing unrelated files (Nix
# modules, Markdown docs, CSS, secrets, …) does NOT invalidate the Go
# build and force a multi-minute recompile on every `nixos-rebuild switch`.
#
# Usage
# -----
#   goSrc = import ./lib/go-src.nix { src = self; lib = lib; };   # in flake.nix
#   goSrc = import ../../lib/go-src.nix { src = ./../..; lib = lib; };  # in a module
#   pkgs.buildGoModule { src = goSrc; ... }
#
# Rationale
# ---------
# Before this helper the Go packages used `src = self` / `cleanSource ./../..`
# i.e. the entire repository. Any `git commit` / config tweak changed the
# source hash and rebuilt ivali, bw-tui and the bot from scratch. Filtering
# to Go-only inputs keeps the hash constant unless Go code actually changes.
#
# Ownership
# ---------
# Consumed by flake.nix (ivali, bw-tui, ivali-bot) and any future Go tool.
#
##############################################################################

{ src, lib }:

lib.cleanSourceWith {
  src = src;

  # Keep a path iff it is a directory (so the tree structure is preserved)
  # or a Go / module file. Everything else (nix, md, css, yaml, png, …)
  # is dropped, so it cannot affect the build hash.
  filter = name: type:
    let
      base = builtins.baseNameOf name;
    in
    type == "directory"
    || lib.hasSuffix ".go" base
    || base == "go.mod" || base == "go.sum"
    || base == "go.work" || base == "go.work.sum"
    || lib.hasSuffix ".mod" base
    || lib.hasSuffix ".sum" base;
}
