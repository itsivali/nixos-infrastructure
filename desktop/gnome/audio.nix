{ config, lib, pkgs, ... }:

{
  config = lib.mkIf config.ivali.desktop.gnome.enable {
    services.pipewire = {
      enable = true;
      audio.enable = true;
      pulse.enable = true;
      wireplumber.enable = true;
      jack.enable = true;
    };
  };
}
