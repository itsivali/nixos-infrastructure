# configuration.nix
#
# ─────────────────────────────────────────────────────────────────────────────
# TOP-LEVEL MODULE REGISTRY
# ─────────────────────────────────────────────────────────────────────────────
# Auto-discovers every top-level folder that contains a default.nix and treats
# it as a NixOS domain module. No manual registration needed — just create a
# folder with a default.nix and it will be imported on the next rebuild.
#
# Pinned (never auto-discovered):
#   hosts/hardware-configuration.nix  — machine-specific hardware config
#   hosts/laptop.nix                  — host identity and per-host options
#
# Explicitly imported (not auto-discovered):
#   desktop          — desktop environment domain module
#   packages/system  — system-wide package set (CLI + desktop)
#
# Excluded from discovery:
#   home      — Home Manager configs; wired up in flake.nix directly
#   hosts     — pinned above; not a domain module
#   lib       — Nix helper functions, not modules
#   packages  — package sets, not modules (except packages/system, imported above)
#   scripts   — shell scripts
#   secrets   — SOPS secret files
#   tests     — NixOS tests; imported separately if needed
#
{ ... }:
let
  root = ./.;

  # Folders that live at the repo root but are NOT NixOS domain modules
  # (or are imported explicitly above).
  excluded = [
    "desktop"
    "home"
    "hosts"
    "lib"
    "packages"
    "scripts"
    "secrets"
    "tests"
  ];

  entries = builtins.readDir root;

  # Every non-excluded subdirectory that has a default.nix is a domain module.
  domainModules = map
    (name: root + "/${name}")
    (builtins.filter
      (name:
        entries.${name} == "directory"
        && !(builtins.elem name excluded)
        && builtins.pathExists (root + "/${name}/default.nix")
      )
      (builtins.attrNames entries));
in
{
  imports =
    # ── Pinned host files (order matters — hardware before identity) ────────
    [
      ./hosts/hardware-configuration.nix
      ./hosts/laptop.nix
    ]
    # ── Explicit domain modules ────────────────────────────────────────────
    ++ [
      ./desktop
      ./packages/system
    ]
    # ── Auto-discovered domain modules ──────────────────────────────────────
    ++ domainModules;

}
