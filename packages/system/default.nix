# packages/system/default.nix
# System-wide packages — combines cli + desktop for environment.systemPackages.
{ pkgs }:
(import ../cli { inherit pkgs; })
++ (import ../desktop { inherit pkgs; })
