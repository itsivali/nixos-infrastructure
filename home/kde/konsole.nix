##############################################################################
#
# Home Manager — Konsole
#
# Purpose
# -------
# Konsole profile and default profile configuration.
# All declarative settings are in plasma.nix (programs.plasma.dataFile
# and programs.plasma.configFile."konsolerc").
#
# Ownership
# ---------
# programs.plasma
#
##############################################################################

{ ... }:

{
  # Konsole config is handled declaratively via programs.plasma in
  # home/kde/plasma.nix — Mokka.profile + konsolerc DefaultProfile.
}
