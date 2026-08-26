# home/gnome

Per-user GNOME desktop configuration (strictly unprivileged, declarative dconf
  only). Imported by `home/default.nix` when the host enables
`ivali.desktop.gnome`.

## Purpose

Everything the user wants GNOME to look and behave like, expressed in dconf.
System-level bits (the GNOME session, GDM, extension *packages*) live in
`desktop/gnome/*`; this module only writes per-user GSettings values.

## Files

| File | Scope |
|------|-------|
| `nautilus.nix` | Nautilus list view + columns, "Open in Terminal" → gnome-terminal, GTK file-chooser |
| `extensions.nix` | Enabled extensions (the 10 curated UUIDs) + per-extension preferences |
| `shell.nix` | Dock favorites, window buttons, custom keybindings, touchpad, power/idle, Gruvbox wallpaper, accessibility |

## Options

This module adds no NixOS/Home Manager options; it is gated by the host-level
`ivali.desktop.gnome.enable`.

Key dconf paths written:

- `org/gnome/shell` → `favorite-apps`, `enabled-extensions`
- `org/gnome/desktop/interface` → `color-scheme`, `accent-color` (in `home/theming.nix`)
- `org/gnome/desktop/background` / `screensaver` → Gruvbox wallpaper + lockscreen
- `org/gnome/settings-daemon/plugins/power` → AC/battery suspend, lid-close policy
- `org/gnome/desktop/a11y/*` → universal-access indicator, on-screen keyboard, sticky keys

## Troubleshooting

- **Extension not loading:** confirm the extension *package* is installed
(`desktop/gnome/extensions.nix`), the UUID is in `enabled-extensions`, then
run `gnome-extensions enable <uuid>` once and re-login.
- **Shell theme not applying:** confirm `gnome-shell-gruvbox-theme` is
installed (`nix build .#gnome-shell-gruvbox-theme`), the user-themes
extension is enabled, and
`org.gnome.shell.extensions.user-theme.name` is `gruvbox-shell`.
- **Settings not applied:** the dconf service is enabled automatically when
`dconf.settings` is populated — `systemctl --user status dconf-service`.
- **dconf "unknown key" warnings:** schema keys are version-sensitive; the
values here were verified against GNOME 50 at the pinned nixpkgs rev. On a
newer rev, re-verify with `gsettings list-keys <schema>`.

## Keyboard Shortcuts

All shortcuts are designed for right-hand accessibility.

### GNOME Desktop

| Shortcut | Action |
|----------|--------|
| `Ctrl+.` | Launch GNOME Terminal |
| `Super+B` | Launch Firefox |
| `Super+E` | Launch Nautilus (Files) |
| `Super+Q` | Close window |
| `Alt+F4` | Close window |
| `Super` | Toggle Overview |

### Zsh Shell

| Shortcut | Action |
|----------|--------|
| `Tab` | Menu expand or complete |
| `↑` | Search history (prefix) |
| `↓` | Search history (prefix) |
| `Ctrl+/` | Open lazygit |
| `Ctrl+C` | Cancel current command |
| `Ctrl+D` | Exit shell |
| `Ctrl+R` | Reverse history search |
| `Ctrl+A` | Move to beginning of line |
| `Ctrl+E` | Move to end of line |
| `Ctrl+U` | Kill line before cursor |
| `Ctrl+K` | Kill line after cursor |
