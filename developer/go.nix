##############################################################################
#
# Go Toolchain
#
# Purpose
# -------
# Go programming language runtime and development tools.
#
# Ownership
# ---------
# environment.systemPackages for Go tooling
#
# Does NOT Own
# ------------
# - Go cache paths (home/environment/variables.nix)
# - Go source filter (lib/go-src.nix)
# - Go binary cache (caching/default.nix)
# - Go binaries built in flake.nix (ivali, bw-tui)
#
##############################################################################

{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    go
    gopls
    gotools
    go-tools
    delve
  ];
}
