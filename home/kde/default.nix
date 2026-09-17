##############################################################################
#
# Home Manager — KDE Composition Root
#
# Purpose
# -------
# Compose all KDE-specific Home Manager modules.
# This file contains imports only.
#
##############################################################################

{ hostSpec, ... }:

let
  hostConfig = hostSpec.config or { };
  kdeEnabled = hostConfig.ivali.desktop.kde.enable or false;
in
{
  imports = [
    ./plasma.nix
    ./konsole.nix
    ./dolphin.nix
    ./remote-desktop.nix
    ./webapps.nix
  ]
  ++ (if kdeEnabled then [ ] else [ ]);
}
