##############################################################################
#
# Docker
#
# Purpose
# -------
# Docker container runtime configuration.
#
# Ownership
# ---------
# virtualisation.docker
#
# Does NOT Own
# ------------
# - Shell defaults (developer/shell.nix)
# - Language toolchains (developer/languages.nix)
# - Podman or other runtimes (N/A)
#
##############################################################################

{ ... }:

{
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };
}
