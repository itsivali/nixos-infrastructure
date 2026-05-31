# packages/system/default.nix
# Returns a flat list of derivations for use in both:
#   - flake.nix:  packages.${system}.system = pkgs.buildEnv { paths = ...; }
#   - configuration.nix: environment.systemPackages = (import ...) ++ [ ... ]
{ pkgs }:
# Use ++ (list concatenation), NOT + (string/integer addition).
(import ../terminal { inherit pkgs; })
++ (import ../gui { inherit pkgs; })