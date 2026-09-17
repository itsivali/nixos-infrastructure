# Context Handoff — GNOME Workstation

## Current Objective

Provide a polished GNOME desktop on NixOS hosts `prague` and `tuscany`:
GNOME Shell over Wayland, GDM display manager, GNOME Remote Desktop,
Catppuccin Mocha Mauve GTK theming, and curated GNOME extensions.

## Completed Work

### Phase 1: Remove KDE Infrastructure
- Removed `desktop/kde/` (default.nix, session.nix, keyboard.nix, remote-desktop.nix)
- Removed `home/kde/` (default.nix, plasma.nix, konsole.nix, dolphin.nix, remote-desktop.nix, webapps.nix)
- Removed `desktop/login/sddm.nix` (replaced by GDM)
- Removed `plasma-manager` flake input and sharedModules entry from `flake.nix`
- Removed KDE-specific environment variables (`QT_QPA_PLATFORM`, `QT_WAYLAND_DISABLE_WINDOWDECORATION`) from `desktop/common/environment.nix`
- Removed KDE portal backend (`xdg-desktop-portal-kde`) in favor of GNOME portal (`xdg-desktop-portal-gnome`) in `desktop/common/portals.nix`

### Phase 2: Create GNOME Infrastructure
- Created `desktop/gnome/default.nix` — barrel + `ivali.desktop.gnome.enable` option
- Created `desktop/gnome/session.nix` — GNOME session, GDM, power management, Bluetooth, libinput, minimal app stack, GNOME Keyring
- Created `desktop/gnome/extensions.nix` — installs curated GNOME extensions (Dash to Dock, Just Perfection, Caffeine, Clipboard Indicator, Vitals)
- Created `desktop/gnome/remote-desktop.nix` — system-level GNOME Remote Desktop (GRD) + Tailscale-only firewall
- Created `desktop/login/gdm.nix` — GDM display manager barrel
- Created `home/gnome/default.nix` — Home Manager barrel
- Created `home/gnome/desktop.nix` — dconf settings (interface, windows, workspaces, keybindings, extensions)
- Created `home/gnome/extensions.nix` — extension dconf configuration
- Created `home/gnome/keyboard.nix` — input sources and media keybindings
- Created `home/gnome/webapps.nix` — M365 web app .desktop entries
- Created `home/gnome/remote-desktop.nix` — per-user GRD dconf settings
- Created `home/gnome/applications.nix` — GNOME MIME type defaults

### Phase 3: Update Shared Desktop Modules
- `desktop/common/portal.nix` — switched to `xdg-desktop-portal-gnome`
- `desktop/common/environment.nix` — removed KDE Qt env vars, kept `NIXOS_OZONE_WL`, `GTK_USE_PORTAL`, `_JAVA_AWT_WM_NONREPARENTING`
- `desktop/common/theme.nix` — updated for GTK theming
- `theme/mokka/default.nix` — removed KDE-specific fields (lookAndFeel, colorScheme, plasmaTheme, kvantum, windowDecoration, splashScreen), updated description
- `desktop/common/platform.nix` — updated comment to reference `ivali.desktop.gnome.enable`
- `desktop/common/packages.nix` — updated comment

### Phase 4: Firefox Configuration
- Removed Motta CSS (`userChrome.css`) — replaced by GNOME-native theming
- Kept all Firefox functionality: Sidebery, Enterprise Policies, privacy hardening, performance settings, ivali profile
- Updated description to "GNOME-optimized"

### Phase 5: Microsoft 365 Web Apps
- Replaced KDE firefoxpwa with native GNOME `.desktop` entries in `home/gnome/webapps.nix`
- Apps: Outlook, Word Online, Excel Online, PowerPoint Online, Teams, OneDrive

### Phase 6: Remote Desktop — GNOME Remote Desktop
- Created `desktop/gnome/remote-desktop.nix` — system-level GRD (PAM auth, Tailscale-only firewall)
- Created `home/gnome/remote-desktop.nix` — per-user RDP dconf settings (mirror-primary, no negotiate-port)
- Removed all KRDP configuration
- No public RDP/port 3389 exposure

### Phase 7: Documentation Updates
- Updated `README.md` — all KDE references replaced with GNOME
- Updated `architecture/dependencies.yaml` — GNOME module paths

## Remaining Work

### LOW
- **Substituter configuration consolidation** (LOW-11): `nix.settings.substituters` split across `system/nix.nix`, `caching/default.nix`, `cache/default.nix`. Acceptable while tracked.

## Key Decisions
- **Display manager**: GDM (GNOME native, Wayland-first)
- **Remote desktop**: GNOME Remote Desktop (GRD) — PAM-based auth, Tailscale-only, no public exposure
- **Extensions**: Dash to Dock, Just Perfection, Caffeine, Clipboard Indicator, Vitals — curated for minimal resource usage
- **Theming**: Catppuccin Mocha Mauve via GTK (Catppuccin GTK + Tela icons + Catppuccin cursors)
- **Web apps**: Native GNOME .desktop entries using Firefox --new-window (replaces firefoxpwa)
- **Firefox**: No Mokka CSS; GNOME-native theming handles visual consistency

## Verification Status
- `nix fmt -- --check .` — PASS
- `nix flake check --no-build` — PASS
- `nix eval .#nixosConfigurations.prague.config.system.build.toplevel.name` — PASS
- `nix eval .#nixosConfigurations.tuscany.config.system.build.toplevel.name` — PASS
- `go build ./...` — PASS
- `go test ./...` — PASS
- `go test ./internal/architecture/... -v` — PASS
- `./ci/check-architecture` — PASS (7/7 checks, 3 pre-existing questionable filesystem boundaries)
- `bash -n scripts/*.sh` — PASS

## Current Branch
`main` (changes staged for commit via ivali flow)
