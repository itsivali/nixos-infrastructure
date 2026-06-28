# packages/user/default.nix
# Returns a flat list of derivations for Home Manager or buildEnv.
{ pkgs }:
(import ../cli { inherit pkgs; })
++ (import ../desktop { inherit pkgs; })
