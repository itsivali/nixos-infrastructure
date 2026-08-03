# home/hyprland/gnome

User-level GNOME application configuration for the Hyprland desktop. Packages
are installed system-wide by `desktop/gnome`; this module only writes
preferences through Home Manager's `dconf.settings`.

## Purpose

Applies the per-user GNOME defaults: Nautilus list view and columns, the
Nautilus "Open in Terminal" context-menu entry (routed to Kitty via
`nautilus-open-any-terminal`), and GTK file-chooser preferences.

## Options

| dconf path | Keys | Meaning |
|------------|------|---------|
| `org/gnome/nautilus/preferences` | `default-folder-viewer`, `show-hidden-files`, `mouse-back-button-to-go-back` | Nautilus browsing defaults |
| `org/gnome/nautilus/list-view` | `default-visible-columns`, `default-zoom-level` | List-view columns and zoom |
| `com/github/stunkymonkey/nautilus-open-any-terminal` | `terminal` | Terminal launched from the Nautilus context menu (`kitty`) |
| `org/gtk/settings/file-chooser` | `sort-directories-first`, `show-hidden` | GTK file-chooser defaults |

## Troubleshooting

- **Nautilus keeps resetting to grid view:** `default-folder-viewer` must be
  set before Nautilus is first launched; apply with `dconf update` /
  `dconf reset -f /org/gnome/nautilus/` if stale local state overrides it.
- **"Open in Terminal" opens the wrong terminal:** change the `terminal` value
  to the desktop-file name of the desired emulator (e.g. `kitty`).
- **Settings not applied:** confirm the dconf service is active
  (`systemctl --user status dconf-service.service`) — it is enabled
  automatically when `dconf.settings` is populated.
