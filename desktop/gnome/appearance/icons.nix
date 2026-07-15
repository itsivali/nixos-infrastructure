{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.desktop.gnome;
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.tela-icon-theme ];
  };
}
