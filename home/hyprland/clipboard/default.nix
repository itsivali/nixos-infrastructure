{ config, lib, pkgs, ... }:

{
  services.cliphist = {
    enable = true;
    extraOptions = [ "-max-items" "100" ];
  };

  wayland.windowManager.hyprland.settings = {
    bind = [
      "SUPER, V, exec, cliphist list | rofi -dmenu -p 'Clipboard' | cliphist decode | wl-copy"
    ];
  };
}
