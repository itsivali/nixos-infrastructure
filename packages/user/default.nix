# packages/user/default.nix
# Returns a flat list of derivations for Home Manager or buildEnv.
{ pkgs }:
# Use ++ (list concatenation), NOT + (string/integer addition).
# Add gui here too if user-level GUI packages are needed; remove if not.
(import ../terminal { inherit pkgs; })
++ (import ../gui { inherit pkgs; })