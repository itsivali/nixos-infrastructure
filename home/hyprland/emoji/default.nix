{ config, lib, pkgs, hostSpec, ... }:

let
  theme = import ../themes { inherit hostSpec; };
in
{
  wayland.windowManager.hyprland.settings = {
    bind = [
      "SUPER, period, exec, rofi -show emoji -theme-str \"* {background-color: ${theme.colors.bg}; text-color: ${theme.colors.fg};} window {border-color: ${theme.colors.accent};}\""
    ];
  };
}
