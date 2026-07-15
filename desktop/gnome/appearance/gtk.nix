{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.desktop.gnome;
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      adw-gtk3
      gnome-themes-extra
    ];
  };
}
