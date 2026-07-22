##############################################################################
#
# Packages System
#
# Purpose
# -------
# Aggregates CLI and desktop packages into environment.systemPackages and
# adds the ivali CLI and Bitwarden TUI from flake packages.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Combine CLI and desktop package sets into environment.systemPackages
# - Install ivali and bw-tui from flake self.packages
#
##############################################################################

# System-wide packages — adds CLI + desktop to environment.systemPackages.
{ config, lib, pkgs, self, ... }:
{
  environment.systemPackages =
    (import ../cli { inherit pkgs; })
    ++ (import ../desktop { inherit pkgs; })
    # Control plane: the ivali CLI and the Bitwarden TUI. The bot service
    # builds its own ivali-bot binary, so only these two are installed here.
    ++ [ self.packages.${pkgs.stdenv.hostPlatform.system}.ivali self.packages.${pkgs.stdenv.hostPlatform.system}.bw-tui ];
}
