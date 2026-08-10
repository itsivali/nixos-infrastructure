##############################################################################
#
# Desktop — Common
#
# Purpose
# -------
# Shared desktop foundation used by every desktop environment: audio, portals,
# GPU, fonts, environment variables, base packages and the design system
# theme. Desktop environments are thin wrappers over this layer.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Barrel for all desktop/common sub-modules
# - Desktop-agnostic services and session configuration
#
##############################################################################

{ ... }:

{
  imports = [
    ./colors.nix
    ./theme.nix
    ./audio.nix
    ./environment.nix
    ./fonts.nix
    ./gpu.nix
    ./packages.nix
    ./portals.nix
  ];
}
