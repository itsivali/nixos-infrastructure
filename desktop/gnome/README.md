# desktop/gnome

System-level GNOME desktop: GNOME Shell session, GDM login manager, the curated
GTK/GNOME application stack, the GNOME Shell extension packages, and Qt theming.
This is the system counterpart to `home/gnome` (user-level settings).

## Purpose

Enables the GNOME Wayland session and installs the curated application set:
Nautilus (file manager), Loupe (images), Papers (PDF), File Roller (archives),
GNOME Text Editor, GNOME Calculator, GNOME Characters, GNOME Logs, Seahorse,
GNOME Terminal (the sole terminal emulator, Gruvbox-themed), the
`nautilus-open-any-terminal` extension, and the GNOME Shell extension packages
(dash-to-panel, blur-my-shell, appindicator, user-themes, just-perfection,
tiling-assistant, clipboard-indicator, impatience, vitals, caffeine). Also
configures Qt applications (LibreOffice, Electron apps) to follow the
GTK/Gruvbox look via the GNOME platform theme — no KDE dependency remains.

## Options

| Option | Default | Meaning |
|--------|---------|---------|
| `ivali.desktop.gnome.enable` | `false` | Gates the whole module; set in `hosts/<name>.nix` |
| `qt.enable` / `qt.platformTheme` | `true` / `"gnome"` | Renders Qt apps through QGnomePlatform |
| `qt.style` | `"adwaita-dark"` | Qt widget style (satisfies the gnome-platform-theme assertion) |
| `services.gnome.gnome-keyring.enable` | `true` | Secret service for NetworkManager/libsecret/SSH |

## Troubleshooting

- **Qt apps look wrong / GTK styling not applied:** confirm `qt.platformTheme = "gnome"` and `qt.style = "adwaita-dark"` are set, then restart the app. QGnomePlatform must be present in `qt.platformPackages` (check the pinned nixpkgs `nixos/modules/config/qt.nix`).
- **Wi-Fi/keyring prompts don't appear:** the GNOME Keyring is started via PAM by the GNOME session; verify with `systemctl --user status` or `loginctl show-session`.
- **Nautilus "Open in Terminal" does nothing:** the extension ships with `hardcode-gsettings.patch`; the terminal is configured in dconf under `com/github/stunkymonkey/nautilus-open-any-terminal` (see `home/gnome/nautilus.nix`).
- **Video/WebP thumbnails missing:** `ffmpegthumbnailer`, `webp-pixbuf-loader` and `libheif` are installed system-wide; restart Nautilus after install.
