

# Context Handoff — Prague Polished GNOME Productivity Desktop

## Core Objective

Build and maintain a polished, productivity-focused **GNOME-only** desktop for `prague`, with `tuscany` compatibility where applicable.

The target architecture is:

- GNOME

- Wayland

- GNOME Search as the sole application launcher

- Curated GNOME extensions

- Firefox + Sidebery

- Microsoft 365 web apps only

- PipeWire + WirePlumber

- NetworkManager

- Tailscale-first private remote GUI access

- Declarative NixOS + Home Manager

- Reproducible, secure, low-maintenance configuration

- Low idle CPU/RAM usage appropriate for the hardware

KDE migration is abandoned. Do not continue or revive KDE as the desktop direction.

# Non-Negotiable Desktop Decisions

## GNOME Only

GNOME is the desktop environment.

Do not introduce:

- KDE Plasma

- Plasma Manager

- SDDM

- KWin

- KDE-specific remote desktop

- KDE-specific portals

- KDE-specific settings infrastructure

GDM + GNOME + Mutter + Wayland should be authoritative.

## GNOME Search Is the Sole Launcher

GNOME Search must remain the authoritative application search/launcher.

**ArcMenu is explicitly forbidden.**

Do not install or configure:

- ArcMenu

- Ulauncher

- Albert

- Rofi

- Wofi

- another application launcher

- another application-search UI

Dash to Dock is only for favorites, running applications, and quick access.

GNOME Workspaces handle window/workspace organization.

# Explicit Repository Audit Commands

Before modifying the repository, perform a structured audit.

Do **not** assume that previous KDE/GNOME work is present, absent, correct, or obsolete.

Run these commands from:

```
\`cd ~/nixos-infrastructure\`
```

## 1. Establish Repository State

```
\`pwd\`  
  
\`git status --short --branch\`  
  
\`git branch --show-current\`  
  
\`git log -10 --oneline --decorate\`  
  
\`git remote -v\`
```

Record:

- current branch

- uncommitted changes

- recent commits

- configured remotes

Do not overwrite unrelated user changes.

## 2. Inspect Repository Structure

```
\`find . -maxdepth 2 -type f | sort\`
```

Then inspect deeper feature/configuration areas:

```
\`find desktop home hosts lib theme modules profiles -type f 2\\\>/dev/null | sort\`
```

If any of those directories do not exist, treat that as an audit finding rather than an error requiring immediate creation.

## 3. Locate Host Configuration

```
\`find . -type f \\\\( -name '\\\*.nix' -o -name 'flake.nix' \\\\) | sort\`
```

Search for the Prague host:

```
\`rg -n --hidden \\\\\`  
  
\`  'prague|testvm|tuscany' \\\\\`  
  
\`  --glob '\\\*.nix' \\\\\`  
  
\`  --glob '!result/\\\*\\\*' \\\\\`  
  
\`  .\`
```

Inspect the flake:

```
\`sed -n '1,260p' flake.nix\`
```

Inspect host configuration files discovered by the previous commands.

## 4. Audit Automatic Imports

Locate the repository's import machinery:

```
\`find . -type f -iname '\\\*auto\\\*import\\\*.nix' -o -iname '\\\*import\\\*.nix' | sort\`
```

If present:

```
\`sed -n '1,320p' lib/auto-imports.nix\`
```

Determine exactly how feature directories and `default.nix` files are discovered.

Do not create manual imports that conflict with the repository's automatic import architecture.

## 5. Search for KDE / Plasma Configuration

Perform a complete repository search:

```
\`rg -n -i --hidden \\\\\`  
  
\`  'kde|plasma|plasma6|plasma-manager|kwin|krdp|sddm|kdePackages|konsole|dolphin|kvantum|qt6ct|xwaylandvideobridge' \\\\\`  
  
\`  --glob '!result/\\\*\\\*' \\\\\`  
  
\`  --glob '!.git/\\\*\\\*' \\\\\`  
  
\`  .\`
```

Also search filenames:

```
\`find . -iname '\\\*kde\\\*' -o \\\\\`  
  
\`       -iname '\\\*plasma\\\*' -o \\\\\`  
  
\`       -iname '\\\*kwin\\\*' -o \\\\\`  
  
\`       -iname '\\\*krdp\\\*' -o \\\\\`  
  
\`       -iname '\\\*sddm\\\*'\`
```

Classify every result as:

1. required for current GNOME system

2. generic/shared infrastructure

3. obsolete KDE-specific configuration

4. uncertain and requiring inspection

Do not blindly delete shared packages merely because they appear in KDE-related results.

## 6. Search for ArcMenu and Competing Launchers

This audit is mandatory:

```
\`rg -n -i --hidden \\\\\`  
  
\`  'ArcMenu|arcmenu|ulauncher|albert|rofi|wofi|application launcher|launcher' \\\\\`  
  
\`  --glob '!result/\\\*\\\*' \\\\\`  
  
\`  --glob '!.git/\\\*\\\*' \\\\\`  
  
\`  .\`
```

Also inspect extension-related configuration:

```
\`rg -n -i --hidden \\\\\`  
  
\`  'gnome.\\\*extension|extension.\\\*gnome|gnomeExtensions|enabledExtensions|extensionPackages' \\\\\`  
  
\`  --glob '\\\*.nix' \\\\\`  
  
\`  .\`
```

Any ArcMenu configuration must be removed from the resulting GNOME configuration.

Do not replace ArcMenu with another launcher.

GNOME Search remains authoritative.

## 7. Audit Existing GNOME Configuration

Search for:

```
\`rg -n -i --hidden \\\\\`  
  
\`  'gnome|gdm|mutter|wayland|xdg-desktop-portal|gnome-shell' \\\\\`  
  
\`  --glob '\\\*.nix' \\\\\`  
  
\`  --glob '\\\*.desktop' \\\\\`  
  
\`  --glob '\\\*.conf' \\\\\`  
  
\`  .\`
```

Inspect likely directories if present:

```
\`find desktop home -maxdepth 3 -type f | sort\`
```

Pay particular attention to:

```
\`home/gnome/\`  
  
\`desktop/gnome/\`  
  
\`desktop/login/gdm.nix\`  
  
\`desktop/remote-desktop/grd.nix\`
```

If these files do not exist, rebuild the architecture cleanly rather than assuming they still exist.

## 8. Audit Desktop Extensions

Search all extension references:

```
\`rg -n -i --hidden \\\\\`  
  
\`  'dash-to-dock|just-perfection|caffeine|clipboard-indicator|vitals|forge|tiling|gnome-shell-extension' \\\\\`  
  
\`  --glob '!result/\\\*\\\*' \\\\\`  
  
\`  --glob '!.git/\\\*\\\*' \\\\\`  
  
\`  .\`
```

Determine:

- which extensions are already installed

- which are enabled

- which are configured

- whether multiple extensions duplicate functionality

- whether obsolete launcher extensions exist

- whether configuration is declarative

Target extension set:

1. Dash to Dock

2. Just Perfection

3. Caffeine

4. Clipboard Indicator

5. Vitals or an equivalent lightweight monitor

6. Forge or equivalent tiling extension only if justified

Do not accumulate extensions unnecessarily.

## 9. Audit Firefox

Search:

```
\`rg -n -i --hidden \\\\\`  
  
\`  'firefox|sidebery|vertical.\\\*tab|webrtc|pipewire|pulseaudio|camera|microphone|screen.\\\*share|wayland|hardware.\\\*accel' \\\\\`  
  
\`  --glob '\\\*.nix' \\\\\`  
  
\`  --glob '\\\*.js' \\\\\`  
  
\`  --glob '\\\*.json' \\\\\`  
  
\`  .\`
```

Inspect:

```
\`home/firefox/\`
```

if present.

Preserve Firefox as the primary browser.

Preserve Sidebery/vertical-tab architecture.

Do not migrate to Zen.

Audit Firefox for:

- native Wayland

- AMD acceleration

- WebRTC

- microphone

- camera

- screen sharing

- PipeWire integration

- Google Meet

- Teams

- Slack

- Discord

## 10. Audit Microsoft 365 Web Apps

Search:

```
\`rg -n -i --hidden \\\\\`  
  
\`  'Microsoft 365|Office 365|Outlook|Word|Excel|PowerPoint|Teams|OneDrive|office|onedrive' \\\\\`  
  
\`  --glob '!result/\\\*\\\*' \\\\\`  
  
\`  --glob '!.git/\\\*\\\*' \\\\\`  
  
\`  .\`
```

The intended model is web applications only.

Do not introduce:

- Wine

- Bottles

- virtual machines

- Windows compatibility layers

The OneDrive account identifier is:

```
\`itsivali@outlook.com\`
```

Never place passwords, OAuth tokens, session cookies, or authentication secrets in Nix configuration.

## 11. Audit Audio

Search:

```
\`rg -n -i --hidden \\\\\`  
  
\`  'pipewire|wireplumber|pulseaudio|alsa|bluetooth.\\\*audio|bluez|audio|sound' \\\\\`  
  
\`  --glob '\\\*.nix' \\\\\`  
  
\`  .\`
```

Determine the authoritative audio stack.

Target:

```
\`PipeWire\`  
  
\`    +\`  
  
\`WirePlumber\`
```

Audit:

- speakers

- microphone

- Bluetooth audio

- USB audio

- HDMI/DisplayPort audio

- browser/WebRTC audio

Avoid running competing audio session managers.

## 12. Audit Networking and Tailscale

Search:

```
\`rg -n -i --hidden \\\\\`  
  
\`  'networkmanager|NetworkManager|wifi|wireless|tailscale|ts.net|dns|routing|firewall' \\\\\`  
  
\`  --glob '\\\*.nix' \\\\\`  
  
\`  .\`
```

Determine:

- NetworkManager authority

- Wi-Fi configuration

- Tailscale configuration

- firewall configuration

- DNS behavior

- routing behavior

- exit-node configuration

- SSH access

Tailscale must not break ordinary Wi-Fi connectivity.

## 13. Audit Remote Desktop

Search:

```
\`rg -n -i --hidden \\\\\`  
  
\`  'remote.\\\*desktop|gnome.\\\*remote|gnome-remote-desktop|rdp|3389|vnc|xrdp|krdp|tailscale' \\\\\`  
  
\`  --glob '!result/\\\*\\\*' \\\\\`  
  
\`  --glob '!.git/\\\*\\\*' \\\\\`  
  
\`  .\`
```

The desired architecture is:

```
\`Phone / Windows App\`  
  
\`        |\`  
  
\`     Tailscale\`  
  
\`        |\`  
  
\`      prague\`  
  
\`        |\`  
  
\`GNOME Remote Desktop\`
```

Do not expose RDP publicly.

Do not open public TCP/UDP 3389 merely to make remote access work.

Audit firewall rules and Tailscale ACL/tag assumptions.

## 14. Audit Portals and Screen Sharing

Search:

```
\`rg -n -i --hidden \\\\\`  
  
\`  'xdg-desktop-portal|xdg.\\\*portal|pipewire.\\\*screen|screen.\\\*share|screencast|gnome.\\\*portal' \\\\\`  
  
\`  --glob '\\\*.nix' \\\\\`  
  
\`  .\`
```

Target:

```
\`xdg-desktop-portal\`  
  
\`+\`  
  
\`GNOME portal backend\`  
  
\`+\`  
  
\`PipeWire screen sharing\`
```

Do not add Flatpak merely as a workaround for broken portal configuration.

## 15. Audit GPU / Wayland / Displays

Search:

```
\`rg -n -i --hidden \\\\\`  
  
\`  'amdgpu|mesa|vulkan|wayland|xwayland|mutter|display|monitor|edid|drm' \\\\\`  
  
\`  --glob '\\\*.nix' \\\\\`  
  
\`  .\`
```

Audit for:

- AMDGPU

- Mesa

- Wayland

- Mutter

- XWayland compatibility

- external displays

- HDMI

- DisplayPort

- suspend/resume

Avoid unnecessary graphics overrides.

## 16. Audit Power Management

Search:

```
\`rg -n -i --hidden \\\\\`  
  
\`  'power|suspend|hibernate|sleep|upower|tlp|thermald|logind|caffeine' \\\\\`  
  
\`  --glob '\\\*.nix' \\\\\`  
  
\`  .\`
```

Determine which component is authoritative for:

- suspend

- lid close

- idle timeout

- battery behavior

- power profiles

Caffeine should only temporarily inhibit sleep.

It must not replace the underlying power-management system.

## 17. Audit Security and Secrets

Search:

```
\`rg -n -i --hidden \\\\\`  
  
\`  'sops|age|secret|secrets|password|token|oauth|credential|private.\\\*key' \\\\\`  
  
\`  --glob '!result/\\\*\\\*' \\\\\`  
  
\`  --glob '!.git/\\\*\\\*' \\\\\`  
  
\`  .\`
```

Verify:

- sops-nix remains authoritative

- secrets are not hardcoded

- credentials are not placed in Home Manager configuration

- no OAuth/session tokens are committed

- Tailscale authentication is handled securely

- firewall rules remain restrictive

Never print secret contents merely for debugging.

## 18. Audit `ivali` CLI

Search:

```
\`rg -n --hidden \\\\\`  
  
\`  'ivali|desktop health|desktop audio|desktop network|desktop bluetooth|desktop display|desktop power|desktop performance' \\\\\`  
  
\`  --glob '!result/\\\*\\\*' \\\\\`  
  
\`  --glob '!.git/\\\*\\\*' \\\\\`  
  
\`  .\`
```

The desired commands are:

```
\`ivali desktop health\`  
  
\`ivali desktop audio\`  
  
\`ivali desktop network\`  
  
\`ivali desktop bluetooth\`  
  
\`ivali desktop display\`  
  
\`ivali desktop power\`  
  
\`ivali desktop performance\`
```

Preserve existing CLI architecture where possible.

Do not create duplicate diagnostic systems.

## 19. Audit Systemd

Search:

```
\`rg -n --hidden \\\\\`  
  
\`  'systemd|systemd.services|systemd.user|systemd.tmpfiles|After=|Before=|Wants=|Requires=' \\\\\`  
  
\`  --glob '\\\*.nix' \\\\\`  
  
\`  .\`
```

Look specifically for:

- duplicate service definitions

- conflicting ordering

- unnecessary background services

- services left over from KDE

- services that should be user-level rather than system-level

- services that increase idle CPU/RAM usage

Avoid unnecessary always-on daemons.

## 20. Audit Packages

Search:

```
\`rg -n --hidden \\\\\`  
  
\`  'environment\\\\.systemPackages|home\\\\.packages|home\\\\.packages|pkgs\\\\.' \\\\\`  
  
\`  --glob '\\\*.nix' \\\\\`  
  
\`  .\`
```

Identify:

- duplicate packages

- obsolete KDE packages

- duplicate utilities

- unnecessary GUI applications

- packages only present because of old workarounds

Do not remove packages solely based on name; inspect their role first.

## 21. Audit Theme and Appearance Configuration

Search:

```
\`rg -n -i --hidden \\\\\`  
  
\`  'theme|gtk|cursor|font|icon|mokka|adwaita|colors|appearance' \\\\\`  
  
\`  --glob '\\\*.nix' \\\\\`  
  
\`  .\`
```

Inspect if present:

```
\`theme/mokka/\`  
  
\`desktop/common/colors.nix\`  
  
\`desktop/common/theme.nix\`  
  
\`home/theming.nix\`  
  
\`boot/plymouth.nix\`
```

Reuse only technically useful generic components.

Do not carry KDE-specific theming architecture into GNOME automatically.

The final visual direction should be:

- modern

- calm

- professional

- restrained

- cohesive

- readable

- maintainable

It should not become an elaborate "rice".

# Existing Historical KDE Work

A previous KDE migration branch existed:

```
\`feature/prague-kde-mokka\`
```

Treat it as historical/obsolete.

Previous KDE-related work included:

```
\`desktop/kde/\`  
  
\`home/kde/\`  
  
\`plasma-manager\`  
  
\`SDDM\`  
  
\`KRDP\`  
  
\`Mokka theme\`  
  
\`KDE portal/environment configuration\`  
  
\`KDE application stack\`
```

Do not revive this architecture.

Previous GNOME-related paths that may have been deleted or altered include:

```
\`home/gnome/\`  
  
\`home/launcher/\`  
  
\`home/webapps/edge-pwa.nix\`  
  
\`desktop/gnome/\`  
  
\`desktop/login/gdm.nix\`  
  
\`desktop/remote-desktop/grd.nix\`
```

Audit their current state before recreating anything.

# Repository Audit Output

After the audit, produce a concise internal inventory containing:

### Keep

Existing components that are compatible with the GNOME architecture.

### Modify

Existing components that should be retained but corrected.

### Remove

KDE-specific, ArcMenu, duplicate, obsolete, or conflicting components.

### Restore

Previously useful GNOME infrastructure that is missing.

### Create

New declarative components required by the target architecture.

### Uncertain

Anything requiring further inspection before modification.

Do not implement until this audit has established the current repository state.

# Engineering Workflow

Follow:

```
\`Audit\`  
  
\`  ↓\`  
  
\`Design\`  
  
\`  ↓\`  
  
\`Tests\`  
  
\`  ↓\`  
  
\`Minimum implementation\`  
  
\`  ↓\`  
  
\`Validation\`  
  
\`  ↓\`  
  
\`Deployment\`  
  
\`  ↓\`  
  
\`Post-deployment verification\`
```

Use strict TDD:

1. Write the test first.

2. Implement the minimum required change.

3. Run the test.

4. Refactor while keeping tests green.

Do not make speculative bulk changes.

# Validation

At minimum run:

```
\`nix flake check\`  
  
\`sudo nixos-rebuild dry-build --flake .\\\#prague\`  
  
\`nix fmt -- --check\`
```

Also run repository-specific tests/checks discovered during the audit.

If formatting currently fails, determine whether the failure is:

- caused by the current changes

- pre-existing

- unrelated

Do not assume a historical failure is still present.

# Deployment

Only deploy after validation succeeds.

Use the repository's existing deployment/GitOps workflow.

Do not commit directly to `main`.

Preferred workflow:

```
\`feature branch\`  
  
\`    ↓\`  
  
\`tests\`  
  
\`    ↓\`  
  
\`flake checks\`  
  
\`    ↓\`  
  
\`dry-build\`  
  
\`    ↓\`  
  
\`review\`  
  
\`    ↓\`  
  
\`merge\`  
  
\`    ↓\`  
  
\`deployment/reconciliation\`
```

Preserve rollback capability through NixOS generations.

Keep recovery paths available:

- TTY

- SSH

- Tailscale

- NixOS generations

- bootloader rollback

# Final Acceptance Criteria

The implementation is complete only when:

- GNOME is the active desktop.

- Wayland is authoritative.

- GDM is the login manager.

- GNOME Search is the sole application launcher.

- ArcMenu is absent.

- No competing launcher is installed.

- Dash to Dock is used only for dock/favorites/running applications.

- GNOME Workspaces remain central to window organization.

- Extensions are curated and non-overlapping.

- Firefox remains the primary browser.

- Sidebery remains the browser tab-management layer.

- Microsoft 365 is handled through web apps.

- Wine/Bottles/VMs are not required.

- PipeWire + WirePlumber provide audio.

- NetworkManager manages networking.

- Tailscale remains the private remote-access boundary.

- GNOME Remote Desktop works through Tailscale without public RDP exposure.

- Bluetooth works.

- External displays work.

- Camera/microphone/screen sharing work through the intended portal/PipeWire stack.

- Suspend/resume works.

- GPU acceleration works appropriately for AMD hardware.

- Idle resource consumption remains reasonable.

- `ivali desktop ...` diagnostics remain available.

- Secrets remain managed securely.

- `prague`, `testvm`, and `tuscany` remain accounted for.

- Existing GitOps/CI/reconciliation architecture remains intact.

- `nix flake check` passes.

- `nixos-rebuild dry-build --flake .\\\#prague` passes.

- Formatting/repository checks pass.

- The system remains rollback-capable.

# Final Engineering Principles

1. **Audit first.**

2. **Do not assume historical configuration is current.**

3. **GNOME is the desktop.**

4. **GNOME Search is the launcher.**

5. **ArcMenu does not exist.**

6. **Native GNOME first.**

7. **Extensions are additions, not substitutes for GNOME.**

8. **Firefox + Sidebery remains the browser architecture.**

9. **Microsoft 365 uses web applications.**

10. **No Wine, Bottles, or VMs.**

11. **Tailscale is the private remote-access boundary.**

12. **NetworkManager owns networking.**

13. **PipeWire/WirePlumber own audio.**

14. **Declarative configuration beats manual fixes.**

15. **TDD before implementation.**

16. **Audit → implement → validate → deploy.**

17. **Never overwrite unrelated user work.**

18. **Never commit directly to `main`.**

19. **Prefer simple, maintainable architecture over clever configuration.**

20. **The final desktop should feel polished because the underlying system is coherent—not because it is overloaded with tweaks.**

This makes the audit an explicit prerequisite rather than leaving OpenCode to infer what “audit first” means.

