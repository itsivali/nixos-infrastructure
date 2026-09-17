# Context Handoff — KDE Migration

## Current Objective
Replace GNOME desktop on NixOS hosts `prague` and `tuscany` with KDE Plasma 6 + KWin + Wayland + Garuda Mokka styling.

## Completed Work

### Phase 0-1: Setup
- Created feature branch `feature/prague-kde-mokka`
- Added `plasma-manager` flake input pinned at `a19a2a029fa180911bd89c554dca1616e10f4c1d`
- Wired `plasma-manager.homeModules.plasma-manager` into home-manager sharedModules

### Phase 2: Mokka Theme Package
Created `theme/mokka/`:
- `colors.nix` — KDE color scheme data (Catppuccin Mocha Mauve)
- `terminal.nix` — Konsole color scheme
- `gtk.nix` — GTK theme mappings
- `firefox.nix` — Firefox CSS color data
- `default.nix` — aggregate view
- `konsole-colorscheme.nix` — derivation for Mokka.colorscheme
- `kde-colorscheme.nix` — derivation for Mokka.colors
- `plymouth.nix` — boot splash colors

### Phase 3: KDE System Module
Created `desktop/kde/`:
- `default.nix` — barrel + `ivali.desktop.kde.enable` option
- `session.nix` — plasma6, SDDM, defaultSession "plasma", power management, Bluetooth, Qt theming, libinput, Mokka color schemes, KDE app stack
- `remote-desktop.nix` — KRDP system module (SystemUserEnabled=true, port 3389, tailscale-only firewall)
- `keyboard.nix` — xkb layout "us", `ctrl:nocaps`

### Phase 4: KDE Home Manager Module
Created `home/kde/`:
- `default.nix` — barrel
- `plasma.nix` — plasma-manager: workspace/theme/effects/shortcuts/configFile/packages
- `konsole.nix` — comment-only (config in plasma.nix)
- `dolphin.nix` — comment-only (config in plasma.nix)
- `remote-desktop.nix` — KRDP user session (krdpserverrc, TLS cert bootstrap, portal permission, systemd units)
- `webapps.nix` — firefoxpwa declarative sites (M365/Word/Excel/PPT)

### Phase 5: SDDM + Host Swap
- Created `desktop/login/sddm.nix`
- Updated `desktop/login/default.nix` to import sddm.nix
- Updated `hosts/prague.nix` to `ivali.desktop.kde.enable = true`
- Updated `hosts/tuscany.nix` to `ivali.desktop.kde.enable = true`

### Phase 6: GNOME Removal
- Deleted `home/gnome/` (all files)
- Deleted `home/launcher/` (default.nix)
- Deleted `home/webapps/` (edge-pwa.nix)
- Deleted `desktop/gnome/` (default.nix, session.nix)
- Deleted `desktop/login/gdm.nix`
- Deleted `desktop/remote-desktop/grd.nix` + `README.md`
- Deleted `theme/gruvbox/` (entire directory)
- Updated `home/default.nix` to remove GNOME gate

### Phase 7: Validation Fixes
Fixed multiple eval errors:
- Merged duplicate `environment.systemPackages` in session.nix
- Fixed duplicate `After` in remote-desktop.nix systemd unit
- Fixed `programs.plasma.krunner.launch` → `programs.plasma.shortcuts."services/org.kde.krunner.desktop"`
- Fixed `xdg-desktop-portal-kde` → `kdePackages.xdg-desktop-portal-kde`
- Fixed ULID keys from 25 to 26 characters
- Fixed defaultSession from "plasmawayland" to "plasma"
- Fixed `kdePackages.kvantum` (not available) — removed
- Fixed `qt6ct` → `kdePackages.qt6ct`
- Fixed `catppuccin-cursors.mocha-mauve` → `catppuccin-cursors.mochaMauve`
- Fixed `services.xserver.xkb.options` to string format
- Fixed `xwaylandvideobridge` (not available) — removed
- Removed `QT_STYLE_OVERRIDE = "kvantum"` from sessionVariables

### Phase 7: Existing File Updates
- `desktop/common/portals.nix` — KDE portal backend
- `desktop/common/environment.nix` — KDE Wayland env vars
- `desktop/common/colors.nix` — Mokka colors
- `desktop/common/theme.nix` — default "mokka"
- `desktop/common/packages.nix` — removed GNOME comments
- `desktop/remote-desktop/default.nix` — GRD removed
- `home/theming.nix` — Mokka GTK theme (catppuccin-gtk, tela-icon-theme, catppuccin-cursors)
- `boot/plymouth.nix` — Mokka two-step theme
- `home/firefox/default.nix` — Mokka CSS theme

## Remaining Work

### Phase 8: Documentation
- Update CONTEXT_HANDOFF.md (this file)
- Update README.md if needed

### Phase 9: Git Workflow
- Run `ivali flow` to commit, push, and create MR

## Key Decisions
- **KRDP password:** System user auth (SystemUserEnabled=true) — RDP clients authenticate with OS account password via PAM. NOT via KWallet/SOPS. The `secrets/rdp.yaml` becomes unused for RDP.
- **Kvantum:** Not available in this nixpkgs version — using Qt6 built-in theming
- **xwaylandvideobridge:** Not available in this nixpkgs version — removed
- **Panel layout:** Deferred to follow-up (default Plasma 6 bottom panel acceptable for this pass)
- **Aurorae decoration:** Deferred to follow-up (using Breeze + Mokka color scheme)

## Verification Status
- `nix eval` — PASS (prague and tuscany)
- `nix flake check --no-build` — PASS (all checks)
- `nix fmt -- --check` — FAIL (pre-existing, not blocking)

## Current Branch
`feature/prague-kde-mokka`
