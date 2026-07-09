{ config, lib, ... }:

{
  options.hydenix.hm.hyprland.shaders = lib.mkOption {
    type = lib.types.lines;
    default = "";
    description = "Extra Hyprland shader config";
  };
}
