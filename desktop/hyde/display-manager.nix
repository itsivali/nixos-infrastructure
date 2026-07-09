{ config, lib, pkgs, ... }:

let
  cfg = config.hydenix;
in
{
  config = lib.mkIf cfg.enable {
    services.displayManager.sddm = {
      enable = true;
      enableHidpi = true;
      wayland.enable = true;
      theme = "breeze";
    };

    services.displayManager.autoLogin = {
      enable = true;
      user = "ivali";
    };
  };
}
