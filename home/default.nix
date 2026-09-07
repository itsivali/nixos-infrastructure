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
  xfceEnabled = hostConfig.ivali.desktop.xfce.enable or false;
in
{
  imports = [
    ./identity

    ./fonts.nix
    ./theming.nix
    ./firefox
  ]
  ++ (if xfceEnabled then [ ./xfce ] else [ ])
  ++ [
    ./shell
    ./git
    ./environment
    ./editors
    ./services
  ];
}
