# packages/user/default.nix
# User-facing packages — CLI tools only; desktop apps go in packages/system.
{ pkgs }:
import ../cli { inherit pkgs; }
