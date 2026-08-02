##############################################################################
#
# Default
#
# Purpose
# -------
# Auto-generated module description.
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  keybinds = ''
    ─── Window Management ───────────────
    SUPER+T/Q         Terminal
    SUPER+C            Close window
    SUPER+W            Toggle float
    SUPER+F            Fullscreen
    SUPER+J            Toggle split
    SUPER+G            Toggle group
    SUPER+SHIFT+F      Pin window
    SUPER+L            Lock screen
    SUPER+X/BACKSPACE  Power menu
    SUPER+N            Notifications

    ─── Navigation ──────────────────────
    SUPER+H/J/K/L      Move focus (vim)
    SUPER+Arrows       Move focus
    SUPER+SHIFT+H/J/K/L  Move window
    ALT+Tab             Cycle focus

    ─── Workspaces ──────────────────────
    SUPER+1-9          Workspace 1-9
    SUPER+0            Workspace 10
    SUPER+SHIFT+1-9    Move to workspace
    SUPER+ALT+1-9      Move silently
    SUPER+CTRL+Arrows  Next/prev workspace
    SUPER+S             Scratchpad

    ─── Apps ────────────────────────────
    SUPER+SPACE/A      App launcher
    SUPER+E            File manager
    SUPER+B            Browser
    SUPER+V            Clipboard

    ─── Media ───────────────────────────
    XF86Audio*         Volume
    XF86Brightness*    Brightness
    Print/SUPER+P      Screenshot

    ─── Theming ─────────────────────────
    SUPER+ALT+T        Night light
    SUPER+ALT+Arrows   Wallpaper
  '';
in
{
  xdg.configFile."hypr/keybinds.txt".text = keybinds;

  wayland.windowManager.hyprland.settings = {
    bind = [
      "SUPER, slash, exec, cat ~/.config/hypr/keybinds.txt | rofi -dmenu -p 'Keybindings' -no-select"
    ];
  };
}
