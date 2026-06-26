# configuration.nix
#
# ─────────────────────────────────────────────────────────────────────────────
# TOP-LEVEL MODULE REGISTRY
# ─────────────────────────────────────────────────────────────────────────────
# This file is the single, stable entry point for all NixOS modules.
# It imports folder-level modules only — never individual files.
#
# Each folder listed here has a default.nix that:
#   1. Holds configuration specific to that domain
#   2. Auto-discovers every *.nix file dropped into its directory
#   3. Auto-discovers sub-folders that contain a default.nix
#
# ┌──────────────────────────────────────────────────────────────────────┐
# │  TO ADD A NEW MODULE                                                 │
# │                                                                      │
# │  Within an existing domain  →  drop a .nix file into that folder.   │
# │    e.g. networking/vpn.nix   gets picked up automatically.          │
# │                                                                      │
# │  New top-level domain       →  create the folder + default.nix,     │
# │    then add ONE line here:  ./my-new-domain                          │
# └──────────────────────────────────────────────────────────────────────┘
{ ... }:
{
  imports = [
    # ── Hardware & host identity (not auto-discovered — too critical) ──
    ./hosts/hardware-configuration.nix
    ./hosts/laptop.nix

    # ── Top-level domains (each has its own auto-discovering default.nix) ──
    ./automation
    ./recovery
    ./boot
    ./networking
    ./security
    ./developer
    ./desktop
    ./observability
    ./ci
  ];

  sops.age.keyFile = "/home/ivali/.config/sops/age/keys.txt";
}
