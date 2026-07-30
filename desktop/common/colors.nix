{ lib, ... }:

let
  gruvbox = import ../../home/hyprland/themes/gruvbox.nix;
  colors = gruvbox.colors // {
    bgHard = gruvbox.colors.bgHard;
    bgSoft = gruvbox.colors.bgSoft;
  };
in
{
  options.ivali.desktop.common.colors = lib.mapAttrs
    (name: _:
      lib.mkOption {
        type = lib.types.str;
        default = colors.${name};
        description = "Gruvbox Dark color: ${name}";
      })
    colors;
}
