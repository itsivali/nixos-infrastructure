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
  gnomeEnabled = hostConfig.ivali.desktop.gnome.enable or false;
in
{
  imports = [
    ./identity

    ./fonts.nix
    ./theming.nix
  ]
  ++ (if gnomeEnabled then [ ./gnome ] else [ ])
  ++ [
    ./shell
    ./git
    ./environment
    ./editors
    ./services
  ];
}
