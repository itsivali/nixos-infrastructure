##############################################################################
#
# Home — NetworkManager Dmenu Config
#
# Purpose
# -------
# Declarative configuration for networkmanager_dmenu, the rofi-based Wi-Fi
# selector used by the Waybar network module. rofi auto-loads the Gruvbox
# theme from ~/.config/rofi/config.rasi, so no theme path is needed.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Write the networkmanager-dmenu config.ini declaratively
# - Support connect/disconnect/forget, saved networks, hidden SSIDs, and
#   obscured passphrase prompts (rofi -password)
#
##############################################################################

{ config, lib, pkgs, ... }:

{
  home.file."networkmanager-dmenu/config.ini".text = ''
    [dmenu]
    dmenu_command = rofi
    highlight = True
    prompt = Networks
    wifi_chars = ▂▄▆█

    [dmenu_passphrase]
    obscure = True
    obscure_color = #282828

    [editor]
    terminal = ${pkgs.kdePackages.konsole}/bin/konsole -e
    gui_if_available = True
    gui = nm-connection-editor

    [nmdm]
    rescan_delay = 5
    show_notifications = True
  '';
}
