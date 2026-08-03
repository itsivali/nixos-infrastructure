# desktop/gnome

System-level GNOME/GTK application stack for the Hyprland desktop. This is the
system counterpart to `home/hyprland/gnome` (user-level settings).

## Purpose

Installs the GTK/GNOME application set that replaces the former KDE stack:
Nautilus (file manager), Loupe (images), Papers (PDF), File Roller (archives),
GNOME Text Editor, GNOME Calculator, GNOME Characters, GNOME Logs, Seahorse,
`hyprpicker`, the GNOME Keyring secret service, and the
`nautilus-open-any-terminal` extension. Also configures Qt applications
(LibreOffice, Electron apps) to follow the GTK/Gruvbox look via the GNOME
platform theme — no KDE dependency remains.

## Options

| Option | Default | Meaning |
|--------|---------|---------|
| `ivali.desktop.hyprland.enable` | `false` | Gates the whole module; set in `hosts/<name>.nix` |
| `qt.enable` / `qt.platformTheme` | `true` / `"gnome"` | Renders Qt apps through QGnomePlatform |
| `qt.style` | `"adwaita-dark"` | Qt widget style (satisfies the gnome-platform-theme assertion) |
| `services.gnome.gnome-keyring.enable` | `true` | Secret service for NetworkManager/libsecret/SSH |

## Troubleshooting

- **Qt apps look wrong / GTK styling not applied:** confirm `qt.platformTheme = "gnome"` and `qt.style = "adwaita-dark"` are set, then restart the app. QGnomePlatform must be present in `qt.platformPackages` (check the pinned nixpkgs `nixos/modules/config/qt.nix`).
- **Wi-Fi/keyring prompts don't appear:** `gnome-keyring-daemon` is started at Hyprland login (`home/hyprland/hypr/default.nix` exec-once) and via PAM (`desktop/login/ly.nix`); verify with `systemctl --user status` or `loginctl show-session`.
- **Nautilus "Open in Terminal" does nothing:** the extension ships with `hardcode-gsettings.patch`; the terminal is configured in dconf under `com/github/stunkymonkey/nautilus-open-any-terminal` (see `home/hyprland/gnome`).
- **Video/WebP thumbnails missing:** `ffmpegthumbnailer`, `webp-pixbuf-loader` and `libheif` are installed system-wide; restart Nautilus after install.
