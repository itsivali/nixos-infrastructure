{ config, lib, pkgs, hostSpec, ... }:

let
  theme = import ../themes { inherit hostSpec; };
in
{
  services.cliphist = {
    enable = true;
    extraOptions = [ "-max-items" "100" ];
  };

  wayland.windowManager.hyprland.settings = {
    bind = [
      "SUPER, V, exec, cliphist list | rofi -dmenu -p 'Clipboard' -theme-str \"* {background-color: ${theme.colors.bg}; text-color: ${theme.colors.fg};} window {border-color: ${theme.colors.accent};}\" | cliphist decode | wl-copy"
    ];
  };
}
