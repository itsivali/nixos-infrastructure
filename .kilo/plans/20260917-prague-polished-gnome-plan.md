# Plan: Prague Polished GNOME Workstation

> **Context:** The repository currently has KDE Plasma 6 as the desktop (merged via `feature/kde-plasma-6-mokka-desktop-migration`). The master prompt mandates converting this to a polished GNOME workstation. The Context Handoff (`CONTEXT_HANDOFF.md`) describes the KDE migration that was completed — it is now stale and must be reconciled with the master prompt's directive: **KDE is abandoned, GNOME is the target.**

> **Source of truth for the target:** The master prompt (this document), not the stale Context Handoff.

---

## Document Map

**Mandatory:**
- `AGENTS.md` — AI operating contract
- `ARCHITECTURE.md` — Target architecture (domain-oriented, hosts compose domains)
- `ARCHITECTURE_AUDIT.md` — Current conformance (historical, needs re-audit)
- `ARCHITECTURE_PROGRESS.md` — Migration progress (Phase 0-7 status)
- `IVALi_FLOW.md` — Git lifecycle
- `CONTEXT_HANDOFF.md` — **STALE**: describes KDE, contradicts master prompt
- `ENGINEERING.md` — Engineering standards

**Applicable:**
- `README.md` — Repository documentation (says "KDE Plasma / Wayland")
- `configuration.nix` — Top-level module registry (auto-imports desktop)
- `hosts/prague.nix`, `hosts/tuscany.nix` — Host specs (set `ivali.desktop.kde.enable = true`)
- `desktop/` — Desktop domain modules (currently KDE)
- `home/` — Home Manager modules (currently KDE)
- `flake.nix` — Flake definition (includes plasma-manager)
- `lib/auto-imports.nix` — Auto-import mechanism
- `desktop/common/*.nix` — Shared desktop foundation (agnostic to DE)
- `theme/mokka/` — Mokka theme (KDE-specific, needs GNOME adaptation)

---

## Phase 0: Establish Baseline (Audit Complete)

**Current repository state:**
- Branch: `main` (up to date with `origin/main`)
- HEAD: `bf8d8a8` — Merge of `feature/kde-plasma-6-mokka-desktop-migration`
- Desktop: KDE Plasma 6 + SDDM + KWin + Wayland + Mokka theme
- Hosts: `prague` and `tuscany` both have `ivali.desktop.kde.enable = true`
- No `desktop/gnome/`, `home/gnome/`, or `ivali.desktop.gnome.*` options exist
- `CONTEXT_HANDOFF.md` describes completed KDE migration (now stale)
- `README.md` says "KDE Plasma / Wayland"

**Key conflict identified:**
- `CONTEXT_HANDOFF.md` says: "Replace GNOME desktop with KDE Plasma 6"
- Master prompt says: "KDE is abandoned, GNOME is the target"
- **Resolution:** Master prompt is authoritative. GNOME is the target.

---

## Phase 1: Remove KDE Infrastructure

### 1.1 Update Host Specifications

**Files:** `hosts/prague.nix`, `hosts/tuscany.nix`

- Remove `ivali.desktop.kde.enable = true` from both
- Do NOT add `ivali.desktop.gnome.enable` yet (created in Phase 2)
- prague.nix: Keep `ivali.desktop.remote-desktop.enable = true` but note this will switch from KRDP to GNOME Remote Desktop in Phase 2

### 1.2 Remove `desktop/kde/` Directory

**Files to remove:**
- `desktop/kde/default.nix` — Defined `ivali.desktop.kde.enable` option
- `desktop/kde/session.nix` — KDE Plasma 6 session, SDDM, Mokka color schemes
- `desktop/kde/remote-desktop.nix` — KRDP system module
- `desktop/kde/keyboard.nix` — xkb config (moved to GNOME session module)

**Rationale:** KDE-specific desktop session modules are obsolete. The GNOME session module will replace these.

### 1.3 Remove `home/kde/` Directory

**Files to remove:**
- `home/kde/default.nix` — KDE Home Manager barrel
- `home/kde/plasma.nix` — plasma-manager configuration (KDE-specific)
- `home/kde/konsole.nix` — KDE terminal config
- `home/kde/dolphin.nix` — KDE file manager config
- `home/kde/remote-desktop.nix` — KRDP user session config
- `home/kde/webapps.nix` — Firefox PWA M365 config (replaced by GNOME .desktop entries)

**Rationale:** KDE Home Manager modules are obsolete. GNOME-specific user config will be created in `home/gnome/`.

### 1.4 Update `home/default.nix`

**File:** `home/default.nix`

- Change `kdeEnabled` check to use GNOME flag (to be defined in Phase 2)
- Change conditional import from `./kde` to `./gnome`
- Keep `./audio` and `./cloud` imports (these are DE-agnostic)

### 1.5 Update `flake.nix`

**File:** `flake.nix`

- Remove `plasma-manager` from inputs
- Remove `plasma-manager.homeModules.plasma-manager` from `home-manager.sharedModules`
- This eliminates the KDE dependency from the flake entirely

### 1.6 Update `desktop/remote-desktop/default.nix`

**File:** `desktop/remote-desktop/default.nix`

- Update comment from "GRD is legacy, KRDP is canonical" to "GNOME Remote Desktop is canonical"
- Prepare for GNOME Remote Desktop configuration (to be added in Phase 2)

### 1.7 Update `desktop/login/` for GDM

**Files:** `desktop/login/default.nix`, create `desktop/login/gdm.nix`

- Replace SDDM reference with GDM
- Create `desktop/login/gdm.nix` with GDM configuration:
  - Enable `services.displayManager.gdm`
  - Set default session to `gnome`
  - Configure GDM greeter (GNOME native)
- Remove `desktop/login/sddm.nix` or update it to be a no-op like `desktop/remote-desktop/default.nix`

---

## Phase 2: Create GNOME Infrastructure

### 2.1 Create `desktop/gnome/default.nix`

**Purpose:** NixOS module that defines `ivali.desktop.gnome.enable` option and activates GNOME.

**Key behavior:**
- Defines `options.ivali.desktop.gnome.enable`
- When enabled, sets `ivali.desktop.enable = true` (shared gate, same pattern as KDE)
- Imports `./session.nix` and `./extensions.nix` (within desktop/gnome/)

### 2.2 Create `desktop/gnome/session.nix`

**Purpose:** System-level GNOME session configuration.

**Configuration:**
- `services.desktopManager.gnome.enable = true`
- `services.displayManager.gdm = { enable = true; defaultSession = "gnome"; }`
- `services.xserver.enable = true` (required by GNOME)
- `programs.dconf.enable = true` (required)
- GNOME session packages: gnome-shell, gnome-session, mutter, gnome-control-center, nautilus, gnome-terminal, gnome-software, gnome-calendar, gnome-contacts, evolution (for email), etesync-eds
- Remove KDE-specific packages (konsole, dolphin, sddm, etc.)
- `powerManagement.enable = true`
- `hardware.bluetooth.enable = true`
- `services.libinput.enable = true` (touchpad config)
- `services.pipewire` + `services.pipewire.wireplumber.enable = true` (moved to common/audio.nix)
- Keyboard: `services.xserver.xkb = { layout = "us"; options = "ctrl:nocaps"; }`
- `services.xserver.displayManager.gdm.wayland = true`

### 2.3 Create `desktop/gnome/extensions.nix`

**Purpose:** Curated GNOME extensions.

**Extensions to install:**
1. **Dash to Dock** — Bottom dock, restrained appearance, transparent, clean favorites/running apps
2. **Just Perfection** — Cleaner GNOME Shell, better spacing/hierarchy
3. **Caffeine** — Temporary sleep inhibitor only (not replacing systemd-logind or power management)
4. **Clipboard Indicator** — Clipboard history with sensible limits (privacy-conscious)
5. **Vitals** — Lightweight system monitor (single instance, no excessive polling)
6. **Optional: Forge** — Only if compatible with installed GNOME version, maintained, stable, no conflicts with Dash to Dock or workspaces

**Configuration (dconf settings):**
- Dash to Dock: bottom position, transparency, icon size, no animation
- Just Perfection: conservative settings, no functionality removed
- Caffeine: temporary inhibition only
- Clipboard Indicator: limited history, no indefinite persistence
- Vitals: lightweight, reasonable polling

### 2.4 Create `home/gnome/default.nix`

**Purpose:** Home Manager barrel for GNOME-specific user config.

**Imports:**
- `./desktop.nix` — GNOME dconf settings
- `./extensions.nix` — GNOME extensions config (if needed at user level)

### 2.5 Create `home/gnome/desktop.nix`

**Purpose:** GNOME desktop preferences via dconf.

**Settings:**
- `org.gnome.desktop.interface` — color-scheme, font, cursor-size
- `org.gnome.desktop.wm.preferences` — theme, button layout
- `org.gnome.shell` — enabled extensions list
- `org.gnome.desktop.session` — idle delay, shutdown settings
- Workspace settings — keyboard navigation, dynamic workspaces
- Dock settings (if not in extensions module)

### 2.6 Create `home/gnome/keyboard.nix`

**Purpose:** User-level keyboard settings for GNOME.

- `org.gnome.desktop.input-sources` — xkb layout us, options ctrl:nocaps
- `org.gnome.settings-daemon.plugins.media-keys` — custom keybindings for workspaces

---

## Phase 3: Update Shared Desktop Modules for GNOME

### 3.1 Update `desktop/common/portal.nix`

**File:** `desktop/common/portals.nix`

- Change `extraPortals` from `pkgs.xdp-desktop-portal-kde` to `pkgs.xdg-desktop-portal-gnome`
- Keep `org.freedesktop.impl.portal.FileChooser = "gtk"` (still correct for GNOME)
- Ensure screen sharing portal is properly configured for PipeWire

### 3.2 Update `desktop/common/environment.nix`

**File:** `desktop/common/environment.nix`

- Keep `_JAVA_AWT_WM_NONREPARENTING`, `GTK_USE_PORTAL`, `NIXOS_OZONE_WL`
- Remove `QT_QPA_PLATFORM` and `QT_WAYLAND_DISABLE_WINDOWDECORATION` (KDE-specific)
- Add GNOME-specific env vars if needed

### 3.3 Update `desktop/common/theme.nix`

**File:** `desktop/common/theme.nix`

- Adapt for GNOME/GTK theming (no KDE-specific theming)
- Mokka colors can still be used via GTK theme (Catppuccin Mocha Mauve)
- No Kvantum, no Aurorae, no KDE color schemes
- Use GNOME-native theming via dconf settings in `home/gnome/desktop.nix`

### 3.4 Update `theme/mokka/default.nix`

**File:** `theme/mokka/default.nix`

- Remove KDE-specific fields: `lookAndFeel`, `colorScheme`, `plasmaTheme`, `kvantum`, `windowDecoration`, `splashScreen`
- Keep: `name`, `displayName`, `colors`, `terminal`, `gtk` (GTK theming is still valid)
- Update description from "Garuda Mokka design system for KDE Plasma 6" to "Catppuccin Mocha Mauve design system for GNOME/GTK"

### 3.5 Verify `desktop/common/audio.nix`

**File:** `desktop/common/audio.nix`

- Already DE-agnostic (PipeWire + WirePlumber)
- No changes needed — works for both GNOME and KDE
- Verify `security.rtkit.enable`, `services.pipewire`, `services.pipewire.wireplumber` are correct

### 3.6 Verify `desktop/common/gpu.nix`

**File:** `desktop/common/gpu.nix`

- Already DE-agnostic (AMDGPU, Mesa)
- No changes needed

### 3.7 Verify `desktop/common/fonts.nix`

**File:** `desktop/common/fonts.nix`

- Already DE-agnostic
- No changes needed

### 3.8 Verify `desktop/common/packages.nix`

**File:** `desktop/common/packages.nix`

- Already DE-agnostic
- No changes needed

---

## Phase 4: Firefox Configuration Update

**File:** `home/firefox/default.nix`

- Remove Mokka CSS (`userChrome.css`) — replaced by GNOME-native theming
- Remove KDE-specific references
- Keep all Firefox functionality:
  - Sidebery extension (vertical tabs, trees/groups)
  - Enterprise Policies (camera/mic/screen-share for Meet/Teams/Slack/Discord/Zoom)
  - Privacy/telemetry hardening
  - Performance settings (WebRender, VAAPI, HTTP/3)
  - ivali profile
- Update description from "Mokka UI" to "GNOME-optimized"
- Ensure `security.sandbox.content.level = 3` remains for camera/mic access
- Verify `.mozilla/firefox` configPath (already set)

---

## Phase 5: Microsoft 365 Web Apps

### 5.1 Remove `home/kde/webapps.nix`

Already removed in Phase 1.3 (firefoxpwa approach is replaced).

### 5.2 Create GNOME Web App Entries

**Location:** `home/gnome/webapps.nix` or integrated into `home/gnome/desktop.nix`

**Target applications:**
- Outlook (https://outlook.live.com)
- Word Online (https://word.office.com)
- Excel Online (https://excel.office.com)
- PowerPoint Online (https://powerpoint.office.com)
- Teams (https://teams.microsoft.com)
- OneDrive (https://onedrive.live.com)

**Mechanism:**
- Create `.desktop` files in `~/.local/share/applications/` via `home.file`
- Each entry uses Firefox `--new-window` with the URL
- Proper icons (use GNOME's web app icon or Firefox)
- `Categories=GNOME;Network;WebBrowser;`
- `StartupWMClass` for proper window grouping
- Named clearly: "Outlook", "Word Online", "Excel Online", etc.
- These will appear in GNOME Search via `.desktop` registration

### 5.3 OneDrive Integration

**File:** `home/cloud/onedrive.nix` (already exists)

- Verify it works on GNOME (it should — uses CLI + systemd user service)
- Authentication: `onedrive --monitor` first run (browser-based SSO)
- Token stored in system keyring (not in Git)
- No changes needed unless GNOME-specific issues arise

---

## Phase 6: Remote Desktop — GNOME Remote Desktop

### 6.1 Create `desktop/gnome/remote-desktop.nix`

**Purpose:** System-level GNOME Remote Desktop configuration.

**Configuration:**
- `services.gnome-remote-desktop.enable = true`
- Configure for Tailscale-only access (via firewall)
- No public RDP exposure (no port 3389 public)
- Authentication: system user auth (PAM-based, NOT via secrets file)

### 6.2 Create `home/gnome/remote-desktop.nix`

**Purpose:** User-level GNOME Remote Desktop config.

**Configuration:**
- `org.gnome.RemoteDesktop` dconf settings
- TLS certificate bootstrap if needed
- Portal permission for screen sharing

### 6.3 Update `hosts/prague.nix`

- Keep `ivali.desktop.remote-desktop.enable = true` but it now points to GNOME RDP
- Update firewall rules for GNOME RDP (Tailscale-only)

### 6.4 Remove KRDP references

- Remove any KRDP-specific configuration
- Ensure no port 3389 is publicly exposed

---

## Phase 7: Documentation Updates

### 7.1 Update `CONTEXT_HANDOFF.md`

**File:** `CONTEXT_HANDOFF.md`

- Complete rewrite: describe GNOME target architecture, not KDE
- Update all completed work sections to reflect GNOME migration
- Update remaining work sections
- Update key decisions
- Update verification status
- Change "Current Branch" to reflect actual branch

### 7.2 Update `README.md`

**File:** `README.md`

- Change "KDE Plasma" → "GNOME" in Technology Stack
- Change "KDE Desktop Architecture" → "GNOME Desktop Architecture"
- Update all KDE references throughout
- Update desktop architecture diagram

### 7.3 Update `desktop/common/platform.nix`

**File:** `desktop/common/platform.nix`

- Update comment from `ivali.desktop.kde.enable = true` to `ivali.desktop.gnome.enable = true`
- No functional change needed (already DE-agnostic via `ivali.desktop.enable`)

### 7.4 Update `desktop/remote-desktop/default.nix`

- Already planned in 1.6
- Update comments to reflect GNOME Remote Desktop as canonical

---

## Phase 8: Verification Gates

Before committing:

1. **Format check:** `nix fmt -- --check .`
2. **Flake check:** `nix flake check --no-build`
3. **Host evaluation:** `nix eval .#nixosConfigurations.prague.config.system.build.toplevel.name`
4. **Host evaluation:** `nix eval .#nixosConfigurations.tuscany.config.system.build.toplevel.name`
5. **Go build:** `go build ./...`
6. **Go tests:** `go test ./...`
7. **Shell validation:** `bash -n scripts/*.sh`
8. **Architecture tests:** `go test ./internal/architecture/... -v`
9. **Architecture linter:** `./ci/check-architecture`

---

## Phase 9: Deployment via ivali flow

After all verification gates pass:

1. `ivali flow start feature "desktop: migrate KDE Plasma 6 to polished GNOME workstation"`
2. Create branch `feature/prague-polished-gnome`
3. Commit all changes via `ivali flow commit`
4. Push via `ivali flow push`
5. Create MR via `ivali flow mr`
6. Verify CI passes
7. Merge via `ivali flow merge`

---

## Risk Assessment

### High Risk
- **Broken evaluation:** Removing `plasma-manager` from flake inputs and removing KDE modules could cause evaluation failures if other modules reference KDE-specific options
- **Missing GNOME packages:** Some GNOME apps may not be available in the pinned nixpkgs
- **Firefox Sidebery compatibility:** Sidebery extension must work under GNOME (it's Firefox-specific, should be fine)

### Medium Risk
- **GDM configuration:** GDM may have different requirements than SDDM on this hardware
- **GNOME extensions compatibility:** Extensions must be compatible with installed GNOME Shell version
- **Mokka theme under GNOME:** GTK theming works differently than KDE theming

### Low Risk
- **OneDrive:** CLI tool is DE-agnostic
- **Audio:** PipeWire/WirePlumber is DE-agnostic
- **Remote Desktop:** GNOME RDP is well-supported

---

## Acceptance Criteria

### Desktop
- [ ] GNOME is the active desktop on prague and tuscany
- [ ] Wayland is the active session
- [ ] GDM is the display manager
- [ ] GNOME Search is the authoritative launcher
- [ ] ArcMenu is absent
- [ ] Dash to Dock works (bottom, restrained)
- [ ] Workspaces work with keyboard navigation
- [ ] Visual design is cohesive (Catppuccin Mocha Mauve via GTK)

### Extensions
- [ ] Dash to Dock, Just Perfection, Caffeine, Clipboard Indicator, Vitals installed
- [ ] All compatible with installed GNOME version
- [ ] No conflicts between extensions
- [ ] Resource usage is reasonable

### Browser
- [ ] Firefox remains primary browser
- [ ] Sidebery remains with vertical tabs
- [ ] Hardware acceleration works
- [ ] Microphone/camera/screen sharing work

### Audio
- [ ] PipeWire + WirePlumber work
- [ ] Speakers, microphone, Bluetooth audio work

### Network
- [ ] NetworkManager works
- [ ] Wi-Fi works
- [ ] Tailscale works
- [ ] Exit-node behavior intentional

### Remote Access
- [ ] GNOME Remote Desktop works
- [ ] Tailscale provides private transport
- [ ] No public RDP/port 3389
- [ ] SSH remains available

### Validation
- [ ] `nix fmt -- --check .` passes
- [ ] `nix flake check --no-build` passes
- [ ] `nix eval .#nixosConfigurations.prague.config.system.build.toplevel.name` passes
- [ ] `nix eval .#nixosConfigurations.tuscany.config.system.build.toplevel.name` passes
- [ ] Go build/tests pass
- [ ] Architecture tests pass
- [ ] `ivali flow` used for all Git operations

---

## Files Summary

### To Remove
- `desktop/kde/` (4 files)
- `home/kde/` (6 files)
- `desktop/login/sddm.nix` (replaced by GDM)
- `flake.nix` plasma-manager input + sharedModules entry

### To Create
- `desktop/gnome/default.nix`
- `desktop/gnome/session.nix`
- `desktop/gnome/extensions.nix`
- `desktop/gnome/remote-desktop.nix`
- `desktop/login/gdm.nix`
- `home/gnome/default.nix`
- `home/gnome/desktop.nix`
- `home/gnome/keyboard.nix`
- `home/gnome/webapps.nix`
- `home/gnome/remote-desktop.nix`

### To Modify
- `hosts/prague.nix`
- `hosts/tuscany.nix`
- `home/default.nix`
- `flake.nix`
- `desktop/common/portal.nix`
- `desktop/common/environment.nix`
- `desktop/common/theme.nix`
- `desktop/remote-desktop/default.nix`
- `desktop/common/platform.nix`
- `theme/mokka/default.nix`
- `home/firefox/default.nix`
- `README.md`
- `CONTEXT_HANDOFF.md`
