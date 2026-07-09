{ config, lib, ... }:

{
  options.hydenix.hm.hyprland.windowrules = lib.mkOption {
    type = lib.types.lines;
    default = "";
    description = "Extra Hyprland window rules";
  };
}
