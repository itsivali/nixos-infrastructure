##############################################################################
#
# Dock Favorites
#
# Purpose
# -------
# Manage pinned apps in Dash-to-Dock declaratively while preserving
# user changes across rebuilds.
#
# How it works
# ------------
# On activation, the script reads the current dconf favorites list.
# - If empty (first boot): sets all default favorites
# - If non-empty: adds any newly installed GUI apps not yet pinned,
#   preserves user removals
#
# Ownership
# ---------
# /org/gnome/shell/favorite-apps
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  # Default favorites for first boot
  defaultFavorites = [
    "firefox.desktop"
    "org.gnome.Console.desktop"
    "org.gnome.Nautilus.desktop"
    "org.gnome.TextEditor.desktop"
    "org.gnome.Extensions.desktop"
    "org.gnome.Settings.desktop"
    "org.gnome.Screenshot.desktop"
    "org.gnome.DiskUtility.desktop"
    "localsend.desktop"
    "us.zoom.Zoom.desktop"
    "obsidian.desktop"
    "vlc.desktop"
    "org.libreoffice.LibreOffice.writer.desktop"
    "org.libreoffice.LibreOffice.calc.desktop"
    "org.libreoffice.LibreOffice.impress.desktop"
  ];

  # Apps that should always be in favorites (installed desktop GUI apps)
  # Format: .desktop file ID
  managedApps = [
    "firefox.desktop"
    "org.gnome.Console.desktop"
    "org.gnome.Nautilus.desktop"
    "org.gnome.TextEditor.desktop"
    "org.gnome.Extensions.desktop"
    "org.gnome.Settings.desktop"
    "org.gnome.Screenshot.desktop"
    "org.gnome.DiskUtility.desktop"
    "localsend.desktop"
    "us.zoom.Zoom.desktop"
    "obsidian.desktop"
    "vlc.desktop"
    "org.libreoffice.LibreOffice.writer.desktop"
    "org.libreoffice.LibreOffice.calc.desktop"
    "org.libreoffice.LibreOffice.impress.desktop"
  ];

  favoritesScript = pkgs.writeShellScript "manage-favorites" ''
    set -euo pipefail

    DCONF="${pkgs.dconf}/bin/dconf"

    CURRENT=$($DCONF read /org/gnome/shell/favorite-apps 2>/dev/null || echo "")

    # If no favorites exist (first boot), set defaults
    if [ -z "$CURRENT" ] || [ "$CURRENT" = "@as []" ] || [ "$CURRENT" = "[]" ]; then
      echo "First boot: setting default favorites..."
      $DCONF write /org/gnome/shell/favorite-apps "[${builtins.concatStringsSep ", " (map (x: "'${x}'") defaultFavorites)}]"
      exit 0
    fi

    # Parse current favorites from dconf format
    # dconf returns: ['app1.desktop', 'app2.desktop']
    CURRENT_CLEAN=$(echo "$CURRENT" | sed "s/^@as //;s/^\[//;s/\]$//;s/'//g;s/, / /g")

    # Build list: start with current, add any managed apps not yet pinned
    NEW_LIST="$CURRENT_CLEAN"
    for app in ${builtins.concatStringsSep " " managedApps}; do
      if ! echo "$NEW_LIST" | grep -qw "$app"; then
        echo "Auto-pinning: $app"
        NEW_LIST="$NEW_LIST $app"
      fi
    done

    # Convert space-separated to dconf array format
    DCONF_ARRAY=$(echo "$NEW_LIST" | tr ' ' '\n' | grep -v '^$' | sed "s/^/'/;s/$/'/" | paste -sd ', ')
    DCONF_ARRAY="[$DCONF_ARRAY]"

    echo "Updating favorites: $DCONF_ARRAY"
    $DCONF write /org/gnome/shell/favorite-apps "$DCONF_ARRAY"
  '';
in
{
  home.activation.favorites = lib.mkAfter ''
    ${favoritesScript}
  '';
}
