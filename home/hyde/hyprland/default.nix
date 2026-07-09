{ config, lib, pkgs, hyde-configs, ... }:

let
  cfg = config.hydenix.hm.hyprland;
  hc = hyde-configs;
in
{
  imports = [
    ./animations.nix
    ./shaders.nix
    ./keybindings.nix
    ./windowrules.nix
    ./monitors.nix
  ];

  options.hydenix.hm.hyprland = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.hydenix.hm.enable;
      description = "Enable Hyprland configuration";
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra Hyprland config lines appended to userprefs.conf";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      hyprutils
      hyprpicker
      hyprcursor
    ];

    home.activation.createHyprConfigs = lib.hm.dag.entryAfter [ "mutableGeneration" ] ''
      mkdir -p "$HOME/.config/hypr/animations"
      mkdir -p "$HOME/.config/hypr/themes"
      mkdir -p "$HOME/.config/hypr/shaders"
      mkdir -p "$HOME/.config/hypr/workflows"
    '';

    home.file = {
      ".local/share/hypr" = {
        source = "${hc}/Configs/.local/share/hypr";
        recursive = true;
      };

      ".config/hypr/hyprland.conf" = {
        source = "${hc}/Configs/.config/hypr/hyprland.conf";
        force = true;
      };

      ".config/hypr/userprefs.conf" = {
        text = cfg.extraConfig;
        force = true;
      };
    };
  };
}
