{ config, lib, ... }:

{
  options.hydenix.hm.hyprland.animations = lib.mkOption {
    type = lib.types.lines;
    default = "";
    description = "Extra Hyprland animation config";
  };
}
