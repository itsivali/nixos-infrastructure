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

{ lib, ... }:

{
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
      desktop = "$HOME/Desktop";
      documents = "$HOME/Documents";
      download = "$HOME/Downloads";
      music = "$HOME/Music";
      pictures = "$HOME/Pictures";
      publicShare = "$HOME/Public";
      templates = "$HOME/Templates";
      videos = "$HOME/Videos";
    };
  };

  home.activation.migrateXdgDirs = lib.mkAfter ''
    # Migrate lowercase XDG directories to canonical uppercase paths
    migrate_dir() {
      local lower="$1" upper="$2"
      if [ -d "$HOME/$lower" ] && [ -d "$HOME/$upper" ]; then
        # Both exist — merge contents from lowercase into uppercase
        find "$HOME/$lower" -mindepth 1 -maxdepth 1 -exec mv -n {} "$HOME/$upper/" \; 2>/dev/null || true
        rmdir "$HOME/$lower" 2>/dev/null || true
      elif [ -d "$HOME/$lower" ] && [ ! -d "$HOME/$upper" ]; then
        # Only lowercase exists — rename to uppercase
        mv "$HOME/$lower" "$HOME/$upper" 2>/dev/null || true
      fi
    }

    migrate_dir "desktop" "Desktop"
    migrate_dir "documents" "Documents"
    migrate_dir "downloads" "Downloads"
    migrate_dir "music" "Music"
    migrate_dir "pictures" "Pictures"
    migrate_dir "public" "Public"
    migrate_dir "templates" "Templates"
    migrate_dir "videos" "Videos"
  '';
}
