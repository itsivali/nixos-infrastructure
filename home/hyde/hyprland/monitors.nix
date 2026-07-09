{ config, lib, ... }:

{
  options.hydenix.hm.hyprland.monitors = lib.mkOption {
    type = lib.types.lines;
    default = "";
    description = "Monitor configuration for Hyprland";
  };

  config.hydenix.hm.hyprland.extraConfig = ''
    # Monitor config
    ${builtins.toString config.hydenix.hm.hyprland.monitors}
  '';
}
