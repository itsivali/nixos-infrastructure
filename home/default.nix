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
  xfceEnabled = hostConfig.ivali.desktop.xfce.enable or false;
in
{
  imports = [
    ./identity

    ./fonts.nix
    ./theming.nix
    ./firefox
  ]
  ++ (if gnomeEnabled then [ ./gnome ./terminal ] else [ ])
  ++ (if xfceEnabled then [ ./xfce ] else [ ])
  ++ [
    ./shell
    ./git
    ./environment
    ./editors
    ./services
  ];
}
