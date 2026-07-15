##############################################################################
#
# Fastfetch
#
# Purpose
# -------
# Own every Home Manager option related to Fastfetch.
#
# Ownership
# ---------
# programs.fastfetch
#
##############################################################################

{ ... }:

{
  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        padding = {
          top = 1;
          right = 2;
        };
      };
      display = {
        separator = " → ";
      };
      modules = [
        "title"
        "separator"
        "os"
        "kernel"
        "uptime"
        "packages"
        "shell"
        "terminal"
        "de"
        "wm"
        "theme"
        "icons"
        "font"
        "cursor"
        "terminalfont"
        "cpu"
        "gpu"
        "memory"
        "swap"
        "disk"
        "battery"
        "locale"
        "break"
        "datetime"
      ];
    };
  };
}
