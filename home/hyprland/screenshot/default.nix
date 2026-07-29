{ config, lib, pkgs, hostSpec, ... }:

let
  screenshotDir = "~/Pictures/screenshots";
in
{
  home.file."Pictures/screenshots/.keep".text = "";

  wayland.windowManager.hyprland.settings = {
    bind = [
      ", Print, exec, grim -g \"$(slurp)\" - | swappy -f -"
      "SUPER SHIFT, P, exec, grim -g \"$(slurp)\" - | wl-copy"
      "SUPER, P, exec, grim - | wl-copy && notify-send 'Screenshot' 'Copied to clipboard'"
      "SUPER ALT, P, exec, grim -g \"$(slurp)\" ${screenshotDir}/$(date +%Y%m%d_%H%M%S).png && notify-send 'Screenshot' 'Saved to ${screenshotDir}'"
    ];
  };
}
