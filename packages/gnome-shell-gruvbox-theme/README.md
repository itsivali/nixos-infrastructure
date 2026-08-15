# packages/gnome-shell-gruvbox-theme

A Gruvbox-Dark recolor of the stock GNOME 50 GNOME Shell theme, loadable via
the **user-themes** extension under the name `gruvbox-shell`.

## Purpose

Give GNOME Shell the same Gruvbox Dark surfaces as the rest of the desktop
(GTK apps, GNOME Terminal, Firefox, the GDM login screen) without
hand-maintaining a thousand lines of shell CSS.

## How it works

It recompiles gnome-shell's own Sass palette with the Gruvbox base colors:

| Adwaita token | Gruvbox |
|---------------|---------|
| `$_base_color_dark` `#222226` | `#282828` (bg) |
| `$bg_color` (dark) `#36363a`  | `#3c3836` (bg1) |
| `$fg_color` (dark) `#ffffff`  | `#ebdbb2` (fg)  |
| `$panel_bg_color` `#000000`   | `#282828` (bg)  |

The theme's `st-mix` / `st-darken` / `-st-accent-color` calls are preserved in
the output and resolved by GNOME Shell's St engine at runtime — so the accent
color follows the active GNOME accent (`accent-color = "orange"` in
`home/theming.nix`), exactly matching the GTK side.

## Options

No options; the package is a plain derivation built from `gnome-shell.src`
(the same source tarball NixOS builds GNOME Shell from), so it tracks the
pinned nixpkgs GNOME version.

## Build & install

```console
nix build .#gnome-shell-gruvbox-theme
```

Installed system-wide by `desktop/gnome/session.nix`. Enable `user-themes` and
set `org.gnome.shell.extensions.user-theme.name = "gruvbox-shell"` (already
done in `home/gnome/extensions.nix`).

## Troubleshooting

- **Theme not shown:** re-login or restart the Shell (`Alt+F2` → `r`), confirm
  the user-themes extension is enabled and the `name` key matches the theme
  directory name `gruvbox-shell`.
- **Build failures on a new GNOME release:** the sed patches target the
  Adwaita variable names in `_default-colors.scss` / `_colors.scss`; verify
  those lines still exist (or extend the patch) when bumping nixpkgs.
- **Accent looks wrong:** this theme never hard-codes the accent; if it looks
  off, check `gsettings get org.gnome.desktop.interface accent-color`.
