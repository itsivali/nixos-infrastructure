# packages/system/default.nix
# System-wide packages — adds CLI + desktop to environment.systemPackages.
{ config, lib, pkgs, ... }:
{
  environment.systemPackages =
    (import ../cli { inherit pkgs; })
    ++ (import ../desktop { inherit pkgs; });
}
