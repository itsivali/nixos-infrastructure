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
  hyprlandEnabled = hostConfig.ivali.desktop.hyprland.enable or false;
in
{
  imports = [
    ./identity

    ./fonts.nix
    ./theming.nix
    ./firefox
  ]
  ++ (if hyprlandEnabled then [ ./hyprland ./terminal ] else [ ])
  ++ [
    ./shell
    ./git
    ./environment
    ./editors
    ./services
  ];
}
