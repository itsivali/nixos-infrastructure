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
  hyprlandEnabled = hostConfig.ivali.desktop.hyprland.enable or false;
in
{
  imports = [
    ./identity

    ./fonts.nix
    ./theming.nix
    ./firefox
  ]
  ++ (if gnomeEnabled then [ ./gnome ] else [ ])
  ++ (if hyprlandEnabled then [ ./hyprland ] else [ ])
  ++ [
    ./shell
    ./git
    ./environment
    ./editors
    ./services
  ];
}
