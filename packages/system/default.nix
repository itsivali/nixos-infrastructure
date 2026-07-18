# packages/system/default.nix
# System-wide packages — adds CLI + desktop to environment.systemPackages.
{ config, lib, pkgs, self, ... }:
{
  environment.systemPackages =
    (import ../cli { inherit pkgs; })
    ++ (import ../desktop { inherit pkgs; })
    # Control plane: the ivali CLI and the Bitwarden TUI. The bot service
    # builds its own ivali-bot binary, so only these two are installed here.
    ++ [ self.packages.${pkgs.system}.ivali self.packages.${pkgs.system}.bw-tui ];
}
