##############################################################################
#
# Theme Engine — Selector Module
#
# Purpose
# -------
# Resolves the active theme based on configuration option or default preset.
# Exposes theme colors and tokens for all Hyprland desktop components.
#
##############################################################################

{ hostSpec, ... }:

let
  hostConfig = hostSpec.config or { };
  selectedThemeName = hostConfig.ivali.desktop.hyprland.theme or "gruvbox";

  themes = {
    gruvbox = import ./gruvbox.nix;
    tokyo-night = import ./tokyo-night.nix;
    catppuccin = import ./catppuccin.nix;
    nord = import ./nord.nix;
    everforest = import ./everforest.nix;
    dracula = import ./dracula.nix;
  };

  activeTheme = themes.${selectedThemeName} or themes.gruvbox;
in
activeTheme
