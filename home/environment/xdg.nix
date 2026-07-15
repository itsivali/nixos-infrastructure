##############################################################################
#
# XDG Configuration
#
# Purpose
# -------
# Configure XDG base directories and user configuration files.
#
# Ownership
# ---------
# xdg.enable
# xdg.userDirs
#
##############################################################################

{ ... }:

{
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
      desktop = "$HOME/desktop";
      documents = "$HOME/documents";
      download = "$HOME/downloads";
      music = "$HOME/music";
      pictures = "$HOME/pictures";
      publicShare = "$HOME/public";
      templates = "$HOME/templates";
      videos = "$HOME/videos";
    };
  };
}
