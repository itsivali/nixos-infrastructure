````markdown
# Context Handoff — GNOME Workstation Remediation

## 1. Mission

Transform the existing NixOS GNOME workstation configuration into a **lean, polished, GNOME-native, reliable, declarative and workflow-focused desktop**.

Primary host:

```text
prague
```

Shared GNOME modules may also affect:

```text
tuscany
```

but changes must remain appropriately scoped.

The target desktop is:

```text
GNOME Shell
+ Wayland
+ GDM
+ GNOME Remote Desktop
+ GNOME/Adwaita visual defaults
+ curated GNOME extensions
+ curated productivity applications
+ Microsoft Edge PWAs for Microsoft 365
+ LAN-first LocalSend
+ Tailscale-secured remote maintenance
+ automatic tmux SSH sessions
+ Apostrophe for Markdown
```

The desktop must feel like **GNOME**, not a recreation of KDE, XFCE, Windows, or another desktop environment.

The philosophy is:

```text
GNOME-native foundation
+
excellent applications
+
small number of useful extensions
+
correct application identities
+
secure networking
+
persistent remote maintenance
+
minimal configuration duplication
```

---

# 2. Critical Context

The repository has already undergone a KDE → GNOME migration.

The current GNOME infrastructure exists and has previously passed static/build checks.

The current task is **not to rebuild GNOME from scratch**.

It is a remediation and integration task covering:

```text
visual consistency
application identities
Edge PWAs for Microsoft 365
LocalSend
Tailscale performance
GNOME extensions
favorites
Markdown handling
SSH/tmux
desktop cleanup
```

Do not flatten or redesign the repository architecture unnecessarily.

---

# 3. Repository Architecture

The repository follows a modular NixOS/Home Manager design with automatic module importing.

Inspect first:

```bash
pwd
git status --short --branch
git branch --show-current
git log -5 --oneline --decorate
```

Inspect the module importer:

```bash
sed -n '1,240p' lib/auto-imports.nix
```

Respect the existing automatic-import conventions.

Do not manually import modules that are already automatically discovered.

Read the repository's architectural guidance before modifying anything:

```text
AGENTS.md
ARCHITECTURE.md
ARCHITECTURE_AUDIT.md
ARCHITECTURE_PROGRESS.md
CONTEXT_HANDOFF.md
CONTRIBUTING.md
DOCS.md
ENGINEERING.md
FIREFOX-PERSISTENCE.md
GEMINI.md
IVALI_FLOW.md
MODULES.md
README.md
SKILLS.md
SUMMARY.md
```

---

# 4. Engineering Method

Use strict TDD/verification-driven development.

For every significant subsystem:

```text
AUDIT
↓
RED
write/define the verification
↓
GREEN
implement the minimum required change
↓
REFACTOR
remove duplication/obsolete configuration
↓
VERIFY
runtime + static validation
```

Do not declare success simply because:

```bash
nix eval
```

passes.

A configuration may evaluate while still having:

```text
broken desktop entries
wrong icons
bad MIME associations
blocked firewall traffic
DERP networking
broken PWA identity
unsafe SSH behavior
```

All relevant behavior must be tested.

---

# 5. NON-NEGOTIABLE TARGET STATE

The final `prague` desktop must have:

### Visual foundation

```text
GTK theme     → GNOME/Adwaita
Icon theme    → GNOME/Adwaita/default
Cursor        → GNOME/Adwaita/default
```

### Favorites

Exactly:

```text
Firefox
Nautilus
LocalSend
Zed
LibreOffice
Notion
GNOME Text Editor
Apostrophe
Obsidian
Zoom
```

in that order.

The Microsoft 365 PWAs (Outlook, Word, Excel, PowerPoint, Teams, OneDrive) appear as
independent launchers installed through Edge. They do not belong in the pinned Dock
favorites unless explicitly added later by the user.

### GNOME extensions

Exactly this curated set unless a compatibility problem forces a documented adjustment:

```text
Dash to Dock
Tiling Assistant
Clipboard Indicator
Caffeine
Vitals
Just Perfection
```

### Markdown

```text
Markdown → Apostrophe
Plain text → GNOME Text Editor
```

### Screenshot

```text
GNOME built-in screenshot functionality
```

No separately installed screenshot application.

### LocalSend

```text
same LAN
↓
LocalSend discovery
↓
TCP/UDP 53317
```

Do not unnecessarily expose LocalSend through Tailscale or the public internet.

### Remote administration

```text
Phone
↓
Tailscale
↓
SSH
↓
interactive shell
↓
tmux "maintenance"
```

### Microsoft 365 PWAs

```text
Outlook
Word
Excel
PowerPoint
Teams
OneDrive
```

Each must have:

```text
own name
own desktop entry
own application icon
own launcher identity
own window identity
```

and must not appear as generic Edge or generic browser.

PWAs are installed and managed through Microsoft Edge's native PWA mechanism.
Firefox remains the primary general-purpose browser and is unaffected.

---

# 6. Explicit Phase-by-Phase Execution Plan

Do the implementation in the following phases.

Do not skip directly to editing files.

---

# PHASE 0 — Repository and Architecture Audit

## Objective

Understand exactly what is currently active before changing anything.

Run:

```bash
git status --short --branch
git branch --show-current
git log -5 --oneline --decorate
```

Then inventory:

```bash
find . -type f | sort
```

Search all desktop configuration:

```bash
rg -n \
  'gnome|gnome-terminal|gnome-console|gnome-screenshot|nautilus|Evolution|firefox|firefoxpwa|PWA|webapp|edge|microsoft-edge|LocalSend|localsend|tailscale|tailscale0|53317|cursor-theme|icon-theme|Catppuccin|Tela|pointerCursor|tmux|favorite-apps|xdg.mimeApps' \
  .
```

Theme audit:

```bash
rg -n -i \
  'catppuccin|tela|gtk-theme|icon-theme|cursor-theme|XCURSOR|GTK_THEME' \
  .
```

Network audit:

```bash
rg -n \
  'networking\.firewall|nftables|iptables|tailscale|LocalSend|53317|41641|tailscale0' \
  .
```

SSH/tmux audit:

```bash
rg -n \
  'programs\.tmux|programs\.zsh|programs\.bash|SSH_TTY|TMUX|openssh|sshd' \
  .
```

KDE residue audit:

```bash
rg -n -i \
  'plasma|plasma6|kwin|kde|plasma-manager|krdp|sddm' \
  .
```

Desktop-entry audit:

```bash
rg -n \
  '\.desktop|favorite-apps|defaultApplications|desktopEntries' \
  .
```

PWA residue audit — search for any remaining Firefox PWA configuration that must be removed:

```bash
rg -n -i \
  'firefoxpwa|pwasforfirefox|programs\.firefoxpwa|firefox.*pwa|pwa.*firefox' \
  .
```

## Exit criteria

Do not begin implementation until you can identify:

```text
current GNOME modules
current package ownership
current theme ownership
current Edge installation (if any)
current PWA configuration (Edge or Firefox-based)
current LocalSend firewall implementation
current Tailscale implementation
current shell/SSH implementation
current favorites
current MIME configuration
any residual firefoxpwa / PWAsForFirefox configuration to remove
```

---

# PHASE 1 — GNOME Visual System Cleanup

## Objective

Remove the old third-party cursor/icon system and restore GNOME-native visuals.

Remove all use of:

```text
catppuccin-cursors.mochaMauve
Catppuccin-Mocha-Mauve-Cursors
catppuccin-mocha-mauve-cursors
```

Search:

```bash
rg -n -i \
  'catppuccin.*cursor|cursor.*catppuccin|mochaMauve'
```

Remove obsolete:

```text
cursor packages
cursor dconf overrides
XCURSOR_THEME
XCURSOR_SIZE
manual cursor overrides
```

where those settings only exist for the old Catppuccin cursor.

Remove Tela as the desktop-wide icon theme:

```bash
rg -n -i 'tela|icon-theme'
```

Do not replace it with another third-party icon pack.

The desired baseline is GNOME/Adwaita.

Audit all overlapping configuration in:

```text
desktop/common/theme.nix
home/gnome/desktop.nix
home/theming.nix
environment variables
dconf
GTK settings
```

There must be one intentional owner for:

```text
GTK appearance
icon appearance
cursor appearance
```

## Exit criteria

Verify after build/runtime:

```bash
gsettings get org.gnome.desktop.interface gtk-theme
gsettings get org.gnome.desktop.interface icon-theme
gsettings get org.gnome.desktop.interface cursor-theme
gsettings get org.gnome.desktop.interface cursor-size
```

No Catppuccin cursor dependency remains.

No Tela desktop-wide icon dependency remains.

---

# PHASE 2 — GNOME Base Applications and Desktop Identity

## Objective

Make the application layer internally consistent.

Prefer:

```text
GNOME Console
Nautilus
GNOME Text Editor
```

as the basic GNOME application layer.

Remove:

```text
gnome-terminal
```

if it is only being used as the terminal.

Remove:

```text
gnome-screenshot
```

completely.

Do not install another screenshot application.

Preserve GNOME's built-in screenshot/keybinding functionality.

Install/ensure:

```text
Firefox
microsoft-edge
LocalSend
Zed
LibreOffice
Notion
Apostrophe
Obsidian
Zoom
```

through the repository's established package ownership mechanism.

`microsoft-edge` is available in nixpkgs and must be declared in the appropriate NixOS
or Home Manager package list for `prague`. Do not declare it for `tuscany` unless that
host requires it.

Do not duplicate packages between NixOS and Home Manager unnecessarily.

## Desktop ID rule

Never assume:

```text
package name == desktop file ID
```

Inspect actual desktop files:

```bash
find /run/current-system/sw/share/applications \
     -type f -name '*.desktop' | sort
```

and relevant per-user locations:

```bash
find ~/.local/share/applications \
     -type f -name '*.desktop' 2>/dev/null | sort
```

Validate launchers with:

```bash
desktop-file-validate <file>
```

## Exit criteria

Every favorite and MIME handler points to an actual desktop entry.

No stale references remain to:

```text
Evolution
GNOME Terminal
gnome-screenshot
old KDE applications
old firefoxpwa launchers
old webapp launchers
```

---

# PHASE 3 — GNOME Favorites

## Objective

Set one exact favorite list.

Target order:

```text
1. Firefox
2. Nautilus
3. LocalSend
4. Zed
5. LibreOffice
6. Notion
7. GNOME Text Editor
8. Apostrophe
9. Obsidian
10. Zoom
```

Implement through the repository's existing dconf/Home Manager architecture.

Do not hard-code unverified desktop IDs.

Discover each ID from the built desktop environment.

Then configure:

```nix
favorite-apps = [
  "<verified-firefox-id>"
  "<verified-nautilus-id>"
  "<verified-localsend-id>"
  "<verified-zed-id>"
  "<verified-libreoffice-id>"
  "<verified-notion-id>"
  "<verified-text-editor-id>"
  "<verified-apostrophe-id>"
  "<verified-obsidian-id>"
  "<verified-zoom-id>"
];
```

Do not include:

```text
Evolution
GNOME Terminal
GNOME Console
Settings
Evince
GNOME Screenshot
GNOME Software
Microsoft Edge
```

as favorites.

Edge itself does not belong in the pinned Dock. The Microsoft 365 PWA launchers
created by Edge are separate applications and may appear in the launcher naturally once
installed, but they are not part of the declaratively pinned list.

## Exit criteria

Run:

```bash
gsettings get org.gnome.shell favorite-apps
```

Verify the exact order.

---

# PHASE 4 — Apostrophe and MIME Associations

## Objective

Make Apostrophe the default Markdown reader/editor.

Install:

```text
apostrophe
```

Find the actual desktop entry before configuring MIME associations.

Configure:

```text
text/markdown
text/x-markdown
```

to open with Apostrophe.

Configure:

```text
text/plain
```

to open with GNOME Text Editor.

Verify common Markdown extensions:

```text
.md
.markdown
.mkd
```

via the correct shared MIME type associations.

Use:

```bash
xdg-mime query default text/markdown
xdg-mime query default text/x-markdown
xdg-mime query default text/plain
```

Expected:

```text
Markdown → Apostrophe
Plain text → GNOME Text Editor
```

## Exit criteria

Double-clicking/launching:

```text
README.md
architecture.md
notes.markdown
```

opens Apostrophe.

---

# PHASE 5 — Microsoft Edge PWA Architecture

## THIS PHASE CONTAINS A RESOLVED DESIGN DECISION

Do not reopen the architecture decision unless Microsoft Edge is technically incapable of
implementing it on the pinned nixpkgs revision.

## Decision

Use **Microsoft Edge's native PWA support** as the Microsoft 365 web-application mechanism.

Edge on Linux ships a first-class PWA runtime. Installing a web application through Edge:

```text
edge://apps → Install site as app
```

or via the address bar's install icon generates:

```text
a proper .desktop entry in ~/.local/share/applications/
a separate application window class
application-specific icons fetched from the site manifest
an entry in the GNOME application launcher
```

This is the correct architecture because:

```text
Edge PWA support is native — no third-party runtime extension required
Microsoft 365 sites publish valid web app manifests that Edge consumes directly
Each installed PWA receives its own process, window class, and desktop identity
Icon assets are taken from the site manifest automatically
The mechanism is stable, maintained, and supported by Microsoft
```

Firefox remains the primary general-purpose browser for all non-Microsoft-365 activity.

Do NOT use:

```text
PWAsForFirefox / firefoxpwa
programs.firefoxpwa
firefox --new-window URL
generic Firefox .desktop wrappers
```

for the Microsoft 365 PWAs.

Do NOT use:

```text
microsoft-edge --app=URL
```

bare wrapper scripts as the final architecture, for the same reason Firefox wrappers were
rejected: a wrapper does not create an independent application identity and does not
persist session, icon, or window-class identity in the same way a properly installed
Edge PWA does.

The correct installation path is Edge's built-in PWA install mechanism, which may be
triggered through the Edge UI or, where Edge supports it, via command-line pre-seeding.

## Required applications

```text
Outlook    → https://outlook.office.com
Word       → https://www.office.com/launch/word
Excel      → https://www.office.com/launch/excel
PowerPoint → https://www.office.com/launch/powerpoint
Teams      → https://teams.microsoft.com
OneDrive   → https://onedrive.live.com
```

---

## PHASE 5A — Verify Edge Availability

Before writing PWA configuration, confirm the Edge package builds and installs cleanly.

```bash
nix build nixpkgs#microsoft-edge --no-link
```

Or inspect the pinned nixpkgs for the attribute:

```bash
nix eval --raw nixpkgs#microsoft-edge.version
```

Confirm:

```text
microsoft-edge package present in pinned nixpkgs
version is a stable channel release
package builds or is available via binary cache
```

Do not proceed to PWA installation steps until Edge is confirmed available.

---

## PHASE 5B — Edge Profile and PWA Data Strategy

Edge PWA installation state lives in the Edge profile directory:

```text
~/.config/microsoft-edge/Default/Web Applications/
```

Desktop entries for installed PWAs are written to:

```text
~/.local/share/applications/
```

Icon assets are stored under:

```text
~/.config/microsoft-edge/Default/Web Applications/<app-id>/
```

Determine the declarative strategy:

**Option A — First-boot provisioning script**

Provide an activation script or Home Manager `activation` block that:

```text
detects whether the six PWAs are already installed
if not, opens Edge to the install URL with a flag that triggers install
records installation state to avoid re-running
```

**Option B — Pre-seeded desktop entries with managed icon assets**

Use `xdg.desktopEntries` in Home Manager to declare the six PWA launchers explicitly,
with icon assets sourced from the Microsoft CDN or bundled in the repository.

Each entry uses the correct Edge app-mode invocation:

```text
Exec=microsoft-edge --app=<URL> --profile-directory=Default
StartupWMClass=<correct-wm-class>
Icon=<path-to-app-icon>
```

The `StartupWMClass` must match the class Edge assigns when the app runs. Inspect this
at runtime:

```bash
xprop WM_CLASS
```

while the PWA window is open.

**Option C — Hybrid**

Pre-seed `xdg.desktopEntries` for immediate launcher availability, and allow Edge to
overwrite/refine the entries on first PWA install through its own mechanism.

Choose the option that best fits the repository's existing Home Manager activation
patterns. Document the chosen approach in this file before implementing it.

---

## PHASE 5C — Single-PWA Smoke Test

Before declaring all six Office applications ready, implement and verify exactly one.

Use Outlook as the test case.

Verify:

```text
Edge launches the site in app-window mode
desktop entry exists and is valid
correct application name shown
correct icon shown (not generic Edge icon)
separate launcher identity in GNOME
separate task-switcher identity
window does not appear as "Microsoft Edge"
session persists between launches
```

Run:

```bash
desktop-file-validate ~/.local/share/applications/<outlook-entry>.desktop
```

Do not proceed to all six applications until the single-PWA test passes.

---

## PHASE 5D — Required PWA Implementation

Implement all six:

```text
Outlook
Word
Excel
PowerPoint
Teams
OneDrive
```

Each must have:

```text
unique application identifier
unique desktop entry
correct application name
correct application icon (not the Edge browser icon)
correct launch target URL
appropriate StartupWMClass
```

Prefer icons sourced from each application's published web app manifest.

Microsoft publishes high-quality SVG and PNG icon assets for all Office 365 applications.
Locate and reference the correct asset for each.

Do not use:

```text
the Edge browser icon (microsoft-edge.svg or equivalent)
a generic browser icon
a placeholder icon
```

for any PWA entry.

---

## PHASE 5E — PWA Desktop Entry Validation

For every PWA:

```text
Outlook
Word
Excel
PowerPoint
Teams
OneDrive
```

inspect the desktop entry:

```text
Name=
Exec=
Icon=
StartupWMClass=
```

Run:

```bash
desktop-file-validate <desktop-file>
```

The GNOME launcher must show:

```text
Outlook icon
Word icon
Excel icon
PowerPoint icon
Teams icon
OneDrive icon
```

and not:

```text
Edge icon
generic browser icon
```

---

## PHASE 5F — PWA Runtime Validation

Launch every PWA.

Verify:

```text
correct application title in title bar
correct icon in task bar and task switcher
separate application identity from Edge browser
separate application identity from other PWAs
correct site loads
session and login state persist
no "Microsoft Edge" label in launcher or task switcher
```

Do not declare PWA work complete solely because a `.desktop` file exists.

---

# PHASE 6 — LocalSend Networking

## Objective

Restore reliable LAN LocalSend while preserving firewall boundaries.

Current problematic pattern:

```text
iifname != "tailscale0"
tcp dport 53317 accept

iifname != "tailscale0"
udp dport 53317 accept
```

This is not the desired model because it does not mean "LAN".

## Required architecture

```text
Wi-Fi/Ethernet
      ↓
LocalSend
      ↓
TCP/UDP 53317
```

Tailscale should primarily provide:

```text
SSH
RDP
remote administration
```

not LocalSend discovery.

---

## PHASE 6A — Discover Interfaces

Run:

```bash
ip -br link
nmcli device status
ip -br addr
```

Identify the actual LAN interface(s).

Do not hard-code an interface name until it is confirmed against the host architecture.

---

## PHASE 6B — Replace Broad Firewall Rules

Replace:

```text
"everything except tailscale0"
```

with explicit interface-scoped LocalSend handling.

LocalSend should not become publicly reachable simply because the interface is not named `tailscale0`.

Preserve the rest of the firewall security model.

---

## PHASE 6C — Runtime Test

Verify:

```bash
ss -lntup | grep 53317 || true
```

Inspect:

```bash
sudo nft list ruleset
```

Then test:

```text
Phone → Prague
Prague → Phone
```

while both devices are on the same Wi-Fi/LAN.

Verify:

```text
discovery works
send works
receive works
```

---

# PHASE 7 — Tailscale Performance and Routing

## Objective

Diagnose why enabling Tailscale on the phone makes networking slow.

Do not assume the problem is GNOME.

Do not immediately alter MTU, routes, firewall rules or exit-node settings without evidence.

---

## PHASE 7A — Direct Connectivity Test

Run:

```bash
tailscale status
tailscale netcheck
```

Then:

```bash
tailscale ping <phone-device>
```

Determine whether the path is:

```text
direct
```

or:

```text
DERP/relay
```

Document the result.

---

## PHASE 7B — Separate Normal Tailscale from Exit Node

Test the phone with:

```text
Tailscale ON
Exit Node = None
```

Expected maintenance path:

```text
Phone
↓
Tailscale
↓
Prague
```

Then separately test:

```text
Phone
↓
Prague exit node
↓
Internet
```

Do not use exit-node performance as proof that ordinary device-to-device Tailscale is slow.

---

## PHASE 7C — Investigate Observed Cause

If the path is relayed or degraded, investigate evidence for:

```text
NAT
UDP reachability
router behavior
MTU
IPv4/IPv6 path
DNS
firewall
exit-node routing
```

Use:

```bash
ip route
ip -6 route
tailscale netcheck
tailscale status
tailscale ping <phone>
```

Do not make unrelated changes simply because they are common Tailscale tuning suggestions.

---

## PHASE 7D — Preserve Exit-Node Capability

If Prague currently advertises itself as an exit node and that is part of the architecture, preserve it.

Do not remove:

```text
advertise exit node
```

solely to mask the performance issue.

Fix the observed network problem instead.

---

# PHASE 8 — GNOME Workflow Extensions

## Objective

Keep GNOME feature-rich without extension bloat.

Final extension set:

```text
Dash to Dock
Tiling Assistant
Clipboard Indicator
Caffeine
Vitals
Just Perfection
```

Keep existing compatible extensions.

Add Tiling Assistant.

Do not introduce:

```text
Blur My Shell
multiple docks
multiple launchers
multiple clipboard managers
multiple tiling systems
desktop widget frameworks
```

unless evidence shows a specific required function cannot otherwise be achieved.

Each extension must have a clear role:

```text
Dash to Dock
→ application/task workflow

Tiling Assistant
→ window organization

Clipboard Indicator
→ clipboard history

Caffeine
→ temporary suspend inhibition

Vitals
→ resource visibility

Just Perfection
→ GNOME shell cleanup
```

The desktop must remain recognizably GNOME.

---

# PHASE 9 — SSH + tmux Maintenance Environment

## Objective

Make phone-based SSH maintenance persistent and resilient.

Use the existing shell architecture.

Prefer a modular file such as:

```text
home/shell/tmux.nix
```

if compatible with the repository's automatic module discovery.

---

## tmux configuration

Enable:

```text
mouse
large history
minimal escape delay
stable terminal type
window numbering
pane numbering
persistent sessions
```

Use a stable maintenance session name:

```text
maintenance
```

---

## Automatic SSH behavior

Interactive SSH sessions should automatically execute:

```text
tmux new-session -A -s maintenance
```

or the equivalent implementation.

The condition MUST distinguish:

```text
interactive SSH
```

from:

```text
non-interactive SSH
```

Use logic conceptually equivalent to:

```bash
if [[ -n "$SSH_TTY" && -z "$TMUX" && -o interactive ]]; then
    exec tmux new-session -A -s maintenance
fi
```

Integrate it with the repository's actual shell framework instead of blindly appending shell code.

---

## Required safety behavior

This must NOT break:

```text
ssh host command
scp
sftp
automation
CI
scripts
Nix commands
Git operations
```

Test both:

```bash
ssh ivali@prague
```

and:

```bash
ssh ivali@prague 'echo hello'
```

Expected:

```text
interactive SSH
→ tmux

non-interactive SSH
→ command executes normally
```

---

# PHASE 10 — GNOME Remote Desktop Review

The existing intended architecture is:

```text
GNOME Remote Desktop
+
PAM authentication
+
Tailscale-only access
+
no public RDP exposure
```

Preserve it.

Do not reintroduce:

```text
KRDP
KDE remote desktop
public 3389
```

Audit:

```bash
rg -n -i \
  'krdp|plasma.*remote|remote.*plasma|3389|xdg-desktop-portal-kde'
```

Do not open public RDP simply because phone remote desktop is being tested.

---

# PHASE 11 — Firefox Persistence Review

Before touching Firefox profile configuration, read:

```text
FIREFOX-PERSISTENCE.md
```

Preserve:

```text
Firefox profile
cookies
bookmarks
extensions
preferences
privacy settings
Sidebery
enterprise policies
performance configuration
```

The Edge PWA architecture must not affect Firefox's profile or configuration in any way.
Firefox and Edge are independent browsers serving distinct roles.

Do not perform destructive profile resets on either browser.

---

# PHASE 12 — Cross-System Desktop Identity Audit

Build an inventory of actual desktop entries:

```bash
find /run/current-system/sw/share/applications \
     -type f -name '*.desktop' \
     -print | sort
```

Check user entries:

```bash
find ~/.local/share/applications \
     -type f -name '*.desktop' \
     -print | sort
```

Cross-check against:

```text
GNOME favorites
MIME defaults
Edge PWA desktop entries
custom launcher entries
```

Everything referenced must actually exist.

Validate all relevant `.desktop` files.

No stale application references may remain.

No residual `firefoxpwa`-generated desktop entries may remain.

---

# PHASE 13 — KDE Contamination Audit

Search:

```bash
rg -n -i \
  'plasma|plasma6|kwin|kde|plasma-manager|krdp|sddm'
```

Do not automatically delete all matches.

Classify each as:

```text
active
shared
historical documentation
unused migration artifact
```

Remove only active obsolete configuration.

The `prague` runtime desktop must remain GNOME-only.

---

# PHASE 14 — Repository Refactor and Cleanup

After functional changes pass, remove obsolete configuration rather than leaving it layered underneath the new implementation.

Audit for:

```text
Catppuccin cursor
Tela icon theme
gnome-screenshot
gnome-terminal
Evolution favorite
firefoxpwa / PWAsForFirefox packages and modules
programs.firefoxpwa configuration
fake Firefox webapps
stale KDE references
duplicate MIME handlers
duplicate package ownership
broad LocalSend firewall rules
obsolete shell startup
```

Run:

```bash
rg -n -i \
  'catppuccin.*cursor|cursor.*catppuccin|Tela-circle|tela-icon|gnome-screenshot|evolution\.desktop|firefoxpwa|pwasforfirefox|programs\.firefoxpwa' \
  .
```

Review every hit.

Do not leave dead configuration merely because it does not currently cause a build error.

---

# PHASE 15 — Documentation

Update repository documentation to reflect the new state.

Documentation must describe:

```text
GNOME desktop architecture
Adwaita visual baseline
GNOME extension set
favorite application order
Markdown → Apostrophe
Firefox as primary browser (general use)
Microsoft Edge as PWA runtime (Microsoft 365)
Edge PWA architecture for Outlook, Word, Excel, PowerPoint, Teams, OneDrive
LocalSend LAN architecture
Tailscale architecture
tmux maintenance architecture
GNOME Remote Desktop
```

Remove obsolete descriptions of:

```text
Catppuccin cursors
Tela desktop-wide icons
Firefox PWA / PWAsForFirefox / firefoxpwa
fake Firefox web apps
KDE
KRDP
```

where those mechanisms have been removed.

Do not create duplicate documentation if an existing document already owns the topic.

---

# PHASE 16 — Static Validation

Run:

```bash
nix fmt -- --check .
```

Then:

```bash
nix flake check --no-build
```

Then:

```bash
nix eval \
  .#nixosConfigurations.prague.config.system.build.toplevel.name
```

and, where affected:

```bash
nix eval \
  .#nixosConfigurations.tuscany.config.system.build.toplevel.name
```

Then perform the repository-standard dry build.

At minimum:

```bash
nix build \
  .#nixosConfigurations.prague.config.system.build.toplevel \
  --no-link
```

Use repository-specific build aliases where they exist.

---

# PHASE 17 — Existing Repository Test Suite

Run:

```bash
go build ./...
go test ./...
go test ./internal/architecture/... -v
./ci/check-architecture
bash -n scripts/*.sh
```

Do not claim prior validation remains valid until these checks are rerun after the changes.

---

# PHASE 18 — Runtime GNOME Validation

After activation:

```bash
echo "$XDG_CURRENT_DESKTOP"
echo "$XDG_SESSION_TYPE"
```

Expected:

```text
GNOME
Wayland
```

where supported.

Check:

```bash
gnome-extensions list --enabled
```

Check favorites:

```bash
gsettings get org.gnome.shell favorite-apps
```

Check visuals:

```bash
gsettings get org.gnome.desktop.interface gtk-theme
gsettings get org.gnome.desktop.interface icon-theme
gsettings get org.gnome.desktop.interface cursor-theme
gsettings get org.gnome.desktop.interface cursor-size
```

---

# PHASE 19 — MIME Validation

Run:

```bash
xdg-mime query default text/markdown
xdg-mime query default text/x-markdown
xdg-mime query default text/plain
xdg-mime query default inode/directory
xdg-mime query default application/pdf
```

Verify:

```text
Markdown → Apostrophe
Plain text → GNOME Text Editor
Directories → Nautilus
```

where configured.

---

# PHASE 20 — LocalSend Runtime Validation

Run:

```bash
ss -lntup | grep 53317 || true
```

Inspect:

```bash
sudo nft list ruleset
```

Check:

```bash
nmcli device status
ip -br addr
```

Then perform actual:

```text
Phone → Prague
Prague → Phone
```

over the same LAN.

LocalSend is not complete until both discovery and transfer work.

---

# PHASE 21 — Tailscale Runtime Validation

Run:

```bash
tailscale status
tailscale netcheck
```

Then:

```bash
tailscale ping <phone-device>
```

Document:

```text
direct
```

or:

```text
DERP
```

Then test:

```text
Phone
↓
Tailscale
↓
Prague
↓
SSH
```

with exit node disabled.

Then test exit-node mode independently.

---

# PHASE 22 — SSH/tmux Validation

From the phone:

```bash
ssh ivali@prague
```

Verify:

```text
interactive shell
↓
tmux
↓
maintenance
```

Disconnect the network.

Reconnect.

Verify the same tmux session remains alive.

Then:

```bash
ssh ivali@prague 'echo hello'
```

Verify no interactive tmux session is created.

---

# PHASE 23 — PWA Runtime Validation

Launch all six:

```text
Outlook
Word
Excel
PowerPoint
Teams
OneDrive
```

For each verify:

```text
correct application-specific icon
correct application name (not "Microsoft Edge")
correct desktop entry
correct site loads
separate application identity
correct task switching
no generic Edge browser identity
no generic browser icon
```

Inspect generated `.desktop` entries.

Run:

```bash
desktop-file-validate
```

on each.

---

# PHASE 24 — Final Visual Validation

Open:

```text
Firefox
Nautilus
LocalSend
Zed
LibreOffice
Notion
GNOME Text Editor
Apostrophe
Obsidian
Zoom
```

Verify:

```text
native-looking GNOME icons
consistent cursor
no missing icons
no generic fallback icons
no Catppuccin cursor
no Tela-wide icon theme
```

Open each PWA:

```text
Outlook
Word
Excel
PowerPoint
Teams
OneDrive
```

Verify:

```text
application-specific icon visible in launcher
application-specific icon visible in task switcher
no generic Edge icon
no generic browser icon
```

---

# PHASE 25 — Final Security Review

Check that changes did not accidentally create:

```text
public SSH
public RDP
public LocalSend
unnecessary WAN ports
broad firewall exceptions
disabled Tailscale security
weakened authentication
```

Inspect:

```bash
sudo nft list ruleset
sudo ss -lntup
sudo ss -lnup
tailscale status
```

Only intended services should be reachable.

---

# PHASE 26 — Final Repository Quality Gate

Run:

```bash
git diff --check
git status --short
git diff --stat
```

Then perform the final obsolete-configuration audit:

```bash
rg -n -i \
  'catppuccin.*cursor|cursor.*catppuccin|Tela-circle|tela-icon|gnome-screenshot|evolution\.desktop|firefoxpwa|pwasforfirefox|programs\.firefoxpwa' \
  .
```

Then:

```bash
rg -n \
  'favorite-apps|defaultApplications|microsoft-edge|53317|tailscale0|SSH_TTY|TMUX|programs\.tmux' \
  .
```

Every remaining match must have an intentional purpose.

---

# 7. Edge PWA Decision — Final Architectural Record

This decision is resolved and should not be reopened during implementation without a
concrete incompatibility in the available `microsoft-edge` nixpkgs package.

## Primary solution

```text
Firefox (primary browser — general use)
+
Microsoft Edge (PWA runtime — Microsoft 365 only)
+
Edge native PWA install mechanism
+
declarative Home Manager desktop entries
```

## Browser role separation

```text
Firefox
→ primary browser
→ general web browsing
→ bookmarks, extensions, privacy configuration
→ Sidebery, enterprise policies, all existing profile state

Microsoft Edge
→ Microsoft 365 PWA runtime only
→ Outlook, Word, Excel, PowerPoint, Teams, OneDrive
→ separate browser profile, no overlap with Firefox
```

The two browsers coexist without interference. Firefox profile state is preserved as-is.

## Why Edge over Firefox PWAs?

Microsoft Edge ships native PWA support on Linux. No third-party runtime extension
is required. Edge reads the web app manifests published by Microsoft 365 applications
and installs them as first-class desktop applications with correct icons, window classes,
and application identities.

Firefox does not implement native manifest-based PWA installation on Linux. The
previously considered `PWAsForFirefox` extension added this capability as a third-party
runtime, but introduced complexity, a separate binary (`firefoxpwa`), Home Manager module
surface area, and a dependency on upstream extension maintenance. Edge's native
implementation is simpler, better supported, and the natural fit for Microsoft 365 apps.

## Why not Firefox wrapper scripts?

Do not use:

```text
firefox --new-window URL
```

because that creates another Firefox window, not an independent application identity.

The same reasoning applies to bare `microsoft-edge --app=URL` wrappers: the goal is true
application identity separation, not browser window cosmetics.

## Why not GNOME Web?

GNOME Web (Epiphany) can create web application launchers but is not the right fit for
Microsoft 365. Edge is the better-tested, Microsoft-supported runtime for these
applications and provides more reliable session handling, notification support, and
compatibility with Microsoft's authentication stack.

## What if Edge is unavailable in the pinned nixpkgs?

Unpin and update nixpkgs to a revision that includes a working `microsoft-edge` package.

Do not fall back to `PWAsForFirefox` or Firefox wrappers.

The architectural invariant is:

```text
native browser PWA runtime
+
unique per-application desktop identities
+
application-specific icons
+
declarative NixOS/Home Manager configuration
```

---

# 8. Existing Verification Baseline

Previously passing checks included:

```text
nix fmt -- --check .
nix flake check --no-build
nix eval .#nixosConfigurations.prague.config.system.build.toplevel.name
nix eval .#nixosConfigurations.tuscany.config.system.build.toplevel.name
go build ./...
go test ./...
go test ./internal/architecture/... -v
./ci/check-architecture
bash -n scripts/*.sh
```

Architecture validation previously reported:

```text
7/7 checks passed
```

with three pre-existing questionable filesystem boundaries.

These are historical results.

Rerun them after implementation before claiming success.

---

# 9. Existing Completed Work

The following work has already been completed and should be preserved unless the remediation requires a correction.

## KDE removal

Removed:

```text
desktop/kde/
home/kde/
desktop/login/sddm.nix
plasma-manager input
KDE shared modules
KDE portal backend
KDE-specific environment variables
KRDP
```

## GNOME infrastructure

Created:

```text
desktop/gnome/default.nix
desktop/gnome/session.nix
desktop/gnome/extensions.nix
desktop/gnome/remote-desktop.nix

desktop/login/gdm.nix

home/gnome/default.nix
home/gnome/desktop.nix
home/gnome/extensions.nix
home/gnome/keyboard.nix
home/gnome/webapps.nix
home/gnome/remote-desktop.nix
home/gnome/applications.nix
```

## Shared desktop modules

Updated:

```text
desktop/common/portal.nix
desktop/common/environment.nix
desktop/common/theme.nix
desktop/common/platform.nix
desktop/common/packages.nix
```

## Firefox

Removed Motta Firefox CSS.

Preserved existing:

```text
Sidebery
Enterprise Policies
privacy hardening
performance settings
Firefox profile/persistence
```

## Remote desktop

Current intended model:

```text
GNOME Remote Desktop
+
PAM
+
Tailscale-only
+
no public 3389
```

## Documentation

Existing GNOME architecture documentation was already updated from the KDE implementation.

Do not undo those completed architectural changes.

Note: any previously written `home/gnome/webapps.nix` configuration using `firefoxpwa`
or `programs.firefoxpwa` must now be replaced with the Edge PWA approach. That file's
new role is either Edge PWA desktop entry declarations or it is removed if Edge's own
install mechanism generates the entries without declarative assistance.

---

# 10. Current Repository Issue Not in Scope

Existing low-priority issue:

```text
LOW-11
```

Substituter configuration remains split across:

```text
system/nix.nix
caching/default.nix
cache/default.nix
```

This can remain tracked.

Do not expand this desktop remediation into an unrelated cache architecture rewrite.

---

# 11. Forbidden Changes

Do not:

```text
reintroduce KDE
reintroduce SDDM
reintroduce KRDP
reintroduce Catppuccin cursors
reintroduce Tela as GNOME-wide icon theme
install a separate screenshot application
use PWAsForFirefox / firefoxpwa for Microsoft 365 apps
use programs.firefoxpwa
use firefox --new-window URL as a PWA substitute
use Firefox wrapper scripts for Office applications
assign Edge browser icon to Office PWAs
assign generic browser icon to Office PWAs
switch Firefox to handle Microsoft 365 PWAs
remove Firefox or damage its profile
open LocalSend broadly to the WAN
open SSH publicly
remove Tailscale security merely to fix connectivity
route phone internet through Prague unnecessarily
install Wine
install a VM
add unnecessary GNOME extensions
flatten repository modules
duplicate package ownership
invent unsupported Nix/Home Manager options
invent desktop IDs
destroy Firefox profile state
destroy Edge profile state
modify unrelated hosts without justification
```

---

# 12. Final Target Architecture

The final workstation should conceptually be:

```text
                           PRAGUE
                              │
                            GNOME
                              │
                 ┌────────────┴────────────┐
                 │                         │
              Adwaita                  Workflow
                 │                         │
          icons + cursor            Dash to Dock
          GTK defaults              Tiling Assistant
                                    Clipboard Indicator
                                    Caffeine
                                    Vitals
                                    Just Perfection

                       Applications
                              │
 ┌─────────┬─────────┬───────┼─────────┬──────────┐
 │         │         │       │         │          │
Firefox  Nautilus LocalSend Zed   LibreOffice   Notion
 │
 │ (general browsing)
 │
Microsoft Edge (PWA runtime — not in Dock)
 │
 ├── Outlook
 ├── Word
 ├── Excel
 ├── PowerPoint
 ├── Teams
 └── OneDrive

GNOME Text Editor
Apostrophe
Obsidian
Zoom

Markdown
   ↓
Apostrophe

LAN
   ↓
LocalSend

Tailscale
   ↓
SSH / GNOME Remote Desktop
   ↓
tmux
   ↓
maintenance
```

The final desktop should exhibit:

```text
GNOME-native visuals
+
minimal extension overhead
+
correct application identities
+
Edge-native Microsoft 365 PWAs
+
Firefox as independent primary browser
+
Adwaita icons/cursor
+
LAN-first LocalSend
+
diagnosed Tailscale connectivity
+
persistent tmux maintenance
+
Markdown → Apostrophe
+
declarative reproducibility
```

---

# 13. Final Deliverable Requirements

At completion, report:

## Changed files

For each changed file:

```text
path
purpose
key change
```

## Removed configuration

Explicitly identify any removed:

```text
Catppuccin cursors
Tela icons
gnome-screenshot
gnome-terminal
stale favorites
firefoxpwa / PWAsForFirefox packages and modules
programs.firefoxpwa configuration
fake Firefox webapps
stale KDE references
duplicate MIME handlers
broad LocalSend firewall rules
obsolete shell code
```

## Added configuration

Explicitly identify:

```text
microsoft-edge package
Apostrophe
Tiling Assistant
new favorites
Edge PWA desktop entries (Outlook, Word, Excel, PowerPoint, Teams, OneDrive)
LocalSend firewall architecture
tmux
GNOME-native visual baseline
```

## Test results

Report the actual result of:

```text
nix fmt
nix flake check
nix eval
nix build/dry-build
Go tests
architecture tests
GNOME runtime checks
MIME checks
LocalSend checks
Tailscale checks
SSH/tmux checks
Edge PWA checks
desktop-entry checks
```

Do not claim any test passed unless it was actually run.

## Remaining issues

For every unresolved issue provide:

```text
problem
evidence
what was attempted
why it remains unresolved
exact next diagnostic/action
```

Never fabricate hardware, Wi-Fi, phone, PWA or network results that cannot be observed from the implementation environment.

---

# 14. Final Success Definition

This task is complete only when the following statement is true:

```text
prague boots into GNOME Wayland through GDM.

GNOME uses its native visual defaults.

No Catppuccin cursor configuration remains.

No Tela desktop-wide icon theme remains.

The separate screenshot package is gone.

The GNOME dock contains exactly the ten requested applications.

Markdown opens in Apostrophe.

Plain text opens in GNOME Text Editor.

LocalSend works between phone and Prague on the same LAN.

LocalSend is not unnecessarily exposed through the public network.

Tailscale provides secure remote access.

Tailscale connectivity has been diagnosed as direct or relayed, rather than guessed.

Exit-node behavior is treated separately from ordinary Tailscale connectivity.

Interactive SSH sessions automatically enter the persistent "maintenance" tmux session.

Non-interactive SSH commands remain unaffected.

Firefox remains the primary general-purpose browser, with its profile and
configuration intact and unmodified.

Microsoft 365 web applications (Outlook, Word, Excel, PowerPoint, Teams, OneDrive)
are installed as PWAs through Microsoft Edge's native PWA mechanism.

Each PWA has its own application identity and application-specific icon.

No PWAsForFirefox / firefoxpwa configuration remains anywhere in the repository.

The entire configuration is declarative and reproducible.

Static validation passes.

Runtime validation passes where the environment permits direct testing.

The repository remains architecturally coherent.
```

Leave the repository ready for review, commit, merge, and deployment through the existing `ivali` workflow.
````
