{ config, lib, pkgs, hyde-configs, ... }:

let
  cfg = config.hydenix.hm;
  hc = hyde-configs;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      hyde-configs
      bibata-cursors
      tela-circle-icon-theme
      wf-recorder
    ];

    home.sessionVariables = {
      HYPRLAND_CONFIG = "${config.xdg.dataHome}/hypr/hyprland.conf";
    };

    fonts.fontconfig.enable = true;

    home.activation.createHydeDirs = lib.hm.dag.entryAfter [ "mutableGeneration" ] ''
      mkdir -p "$HOME/.config/hyde"
      mkdir -p "$HOME/.config/hypr"
      mkdir -p "$HOME/.config/hypr/animations"
      mkdir -p "$HOME/.config/hypr/themes"
      mkdir -p "$HOME/.config/cava"
      mkdir -p "$HOME/.local/state/hyde"
      touch "$HOME/.config/cava/config"
      touch "$HOME/.config/hypr/animations/theme.conf"
      touch "$HOME/.config/hypr/themes/colors.conf"
      touch "$HOME/.config/hypr/themes/theme.conf"
      touch "$HOME/.config/hypr/themes/wallbash.conf"
    '';

    home.file = {
      ".config/hyde/config.toml" = {
        source = "${hc}/Configs/.config/hyde/config.toml";
        force = true;
        mutable = true;
      };

      ".config/hyde/wallbash" = {
        source = "${hc}/Configs/.config/hyde/wallbash";
        recursive = true;
        force = true;
        mutable = true;
      };

      ".config/systemd/user/hyde-ipc.service" = {
        source = "${hc}/Configs/.config/systemd/user/hyde-ipc.service";
      };

      ".local/bin/hyde-shell" = {
        source = pkgs.writeShellScript "hyde-shell" ''
          exec ${pkgs.bashInteractive}/bin/bash "${hc}/Configs/.local/bin/hyde-shell" "$@"
        '';
        executable = true;
      };

      ".local/lib/hyde" = {
        source = "${hc}/Configs/.local/lib/hyde";
        recursive = true;
        executable = true;
        force = true;
      };

      ".local/share/fastfetch/presets/hyde" = {
        source = "${hc}/Configs/.local/share/fastfetch/presets/hyde";
        recursive = true;
      };

      ".local/share/hyde" = {
        source = "${hc}/Configs/.local/share/hyde";
        recursive = true;
        executable = true;
        force = true;
        mutable = true;
      };

      ".local/share/wallbash" = {
        source = "${hc}/Configs/.local/share/wallbash";
        recursive = true;
        force = true;
        mutable = true;
      };

      ".local/share/waybar/includes" = {
        source = "${hc}/Configs/.local/share/waybar/includes";
        recursive = true;
      };

      ".local/share/waybar/layouts" = {
        source = "${hc}/Configs/.local/share/waybar/layouts";
        recursive = true;
      };

      ".local/share/waybar/menus" = {
        source = "${hc}/Configs/.local/share/waybar/menus";
        recursive = true;
      };

      ".local/share/waybar/modules" = {
        source = "${hc}/Configs/.local/share/waybar/modules";
        recursive = true;
      };

      ".local/share/waybar/styles" = {
        source = "${hc}/Configs/.local/share/waybar/styles";
        force = true;
        mutable = true;
        recursive = true;
      };

      ".config/electron-flags.conf" = {
        source = "${hc}/Configs/.config/electron-flags.conf";
      };

      ".local/share/icons/Wallbash-Icon" = {
        source = "${hc}/share/icons/Wallbash-Icon";
        force = true;
        recursive = true;
        mutable = true;
      };

      ".local/share/themes/Wallbash-Gtk" = {
        source = "${hc}/share/themes/Wallbash-Gtk";
        recursive = true;
        force = true;
        mutable = true;
      };
    };
  };
}
