##############################################################################
#
# Home Manager Composition Root
#
# Purpose
# -------
# Compose all Home Manager modules.
#
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
    ./identity

    ./fonts.nix
    ./theming.nix
    ./firefox
  ]
  ++ (if kdeEnabled then [ ./kde ./audio ./cloud ] else [ ])
  ++ [
    ./shell
    ./git
    ./environment
    ./editors
    ./services
  ];
}
