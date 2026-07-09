{ config, lib, pkgs, ... }:

let
  cfg = config.hydenix.hm;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      grim
      slurp
      swappy
    ];
  };
}
