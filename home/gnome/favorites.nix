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
  # Single source of truth for pinned apps (uses live .desktop IDs)
  defaultFavorites = [
    "firefox.desktop"
    "org.gnome.Console.desktop"
    "org.gnome.Nautilus.desktop"
    "org.gnome.TextEditor.desktop"
    "org.gnome.Settings.desktop"
    "LocalSend.desktop"
    "zeditor.desktop"
    "antigravity-ide.desktop"
    "us.zoom.Zoom.desktop"
    "obsidian.desktop"
    "notion-app-enhanced.desktop"
    "ivali-dashboard.desktop"
    "bw-tui.desktop"
    "nvim.desktop"
  ];

  # Apps that should always be in favorites (installed desktop GUI apps)
  # Format: .desktop file ID — kept identical to defaultFavorites to avoid drift
  managedApps = defaultFavorites;

  # Apps that should be removed from favorites if present (e.g. pulled in by
  # an earlier default set, or pinned manually). Removal is enforced on every
  # activation, unlike the add-only managedApps logic.
  removeFavorites = [
    "org.gnome.Extensions.desktop" # GNOME Extensions app
    "org.gnome.DiskUtility.desktop" # Disks
    "org.gnome.Screenshot.desktop"
    "vlc.desktop"
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

    # Remove any apps explicitly flagged for removal
    for app in ${builtins.concatStringsSep " " removeFavorites}; do
      if echo "$NEW_LIST" | grep -qw "$app"; then
        echo "Removing from favorites: $app"
        NEW_LIST=$(echo "$NEW_LIST" | tr ' ' '\n' | grep -vw "$app" | tr '\n' ' ')
      fi
    done

    # Convert space-separated to dconf array format
    DCONF_ARRAY=$(echo "$NEW_LIST" | tr ' ' '\n' | grep -v '^$' | sed "s/^/'/;s/$/'/" | paste -sd',' | sed 's/,/, /g')
    DCONF_ARRAY="[$DCONF_ARRAY]"

    echo "Updating favorites: $DCONF_ARRAY"
    $DCONF write /org/gnome/shell/favorite-apps "$DCONF_ARRAY"
  '';
in
{
  # dconf write needs a D-Bus session bus. HM activation runs as a systemd
  # service without a session (no $DISPLAY), so wrap in dbus-run-session to
  # spawn a transient bus — otherwise `dconf write` fails with
  # "Cannot autolaunch D-Bus without X11 $DISPLAY".
  home.activation.favorites = lib.mkAfter ''
    ${pkgs.dbus}/bin/dbus-run-session --dbus-daemon=${pkgs.dbus}/bin/dbus-daemon -- ${favoritesScript}
  '';

  # Auto-start LocalSend on login (minimized to tray)
  home.file.".config/autostart/localsend-autostart.desktop" = {
    text = ''
      [Desktop Entry]
      Type=Application
      Name=LocalSend
      Comment=Local file sharing
      Exec=${pkgs.localsend}/bin/localsend
      Icon=localsend
      Terminal=false
      X-GNOME-Autostart-enabled=true
      X-GNOME-Autostart-Delay=5
      NoDisplay=true
    '';
  };
}
