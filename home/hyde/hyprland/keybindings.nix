{ config, lib, ... }:

{
  options.hydenix.hm.hyprland.keybindings = lib.mkOption {
    type = lib.types.lines;
    default = "";
    description = "Extra Hyprland keybindings (appended to userprefs.conf)";
  };
}
