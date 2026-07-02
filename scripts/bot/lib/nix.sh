#!/usr/bin/env bash
# lib/nix.sh — NixOS management helpers
#
# Dependencies: nix, nixos-rebuild, git
# Provides:     nix_current_generation
##############################################################################

# Get the current NixOS generation number.
# Usage: gen=$(nix_current_generation)
nix_current_generation() {
  nixos-rebuild list-generations 2>/dev/null | tail -1 | awk '{$1=""; print $0}' | xargs || echo "unknown"
}
