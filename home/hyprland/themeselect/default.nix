{ config, lib, pkgs, hostSpec, ... }:

let
  theme = import ../themes { inherit hostSpec; };
  themeNames = [ "gruvbox" "tokyo-night" "catppuccin" "nord" "everforest" "dracula" ];
  themeScript = pkgs.writeShellScript "theme-selector" ''
    THEME_DIR="$HOME/.config/hyprland"
    THEME_FILE="$THEME_DIR/current-theme"
    mkdir -p "$THEME_DIR"

    THEMES="gruvbox
    tokyo-night
    catppuccin
    nord
    everforest
    dracula"

    CURRENT="gruvbox"
    if [ -f "$THEME_FILE" ]; then
      CURRENT=$(cat "$THEME_FILE")
    fi

    SELECTED=$(echo "$THEMES" | rofi -dmenu -p "Theme (current: $CURRENT)" -theme-str "* {background-color: ${theme.colors.bg}; text-color: ${theme.colors.fg};} window {border-color: ${theme.colors.accent};}")

    if [ -n "$SELECTED" ]; then
      echo "$SELECTED" > "$THEME_FILE"
      notify-send "Theme" "Switched to $SELECTED. Rebuild to apply."
    fi
  '';
in
{
  wayland.windowManager.hyprland.settings = {
    bind = [
      "SUPER SHIFT, T, exec, ${themeScript}"
    ];
  };
}
