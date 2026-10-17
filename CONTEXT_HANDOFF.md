# Context Handoff — GNOME Workstation Remediation & Integration

## 1. Mission

Bring the existing NixOS GNOME workstation implementation to a **polished, GNOME-native, reliable, declarative, secure, observable, and workflow-focused desktop** without unnecessarily redesigning the repository.

Primary host:

```text
prague
```

Shared GNOME modules may also affect:

```text
tuscany
```

but all changes must be correctly scoped so that Prague-specific behavior does not accidentally become global host behavior.

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
+ Tailscale-only LocalSend
+ Tailscale-secured remote administration
+ permanent Prague exit-node capability
+ automatic tmux SSH maintenance sessions
+ Apostrophe for Markdown
```

The desktop must feel like **GNOME**, not like a recreation of KDE, XFCE, Windows, or another desktop environment.

The design philosophy is:

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
explicit host capabilities
+
minimal configuration duplication
+
testable invariants
```

---

# 2. Critical Repository Context

The repository has already undergone a:

```text
KDE → GNOME
```

migration.

The current GNOME infrastructure exists and has previously passed static/build validation.

This task is **not a GNOME rewrite**.

It is a remediation and integration task covering:

```text
visual consistency
application identities
Microsoft 365 Edge PWAs
LocalSend
Tailscale behavior/performance
GNOME extensions
favorites
Markdown handling
SSH/tmux
desktop cleanup
runtime verification
security boundaries
```

Do not flatten or redesign the repository architecture unnecessarily.

Preserve working behavior unless a change is required by evidence.

---

# 3. Relationship to the Master Infrastructure Prompt

This workstation remediation is one workstream within the broader NixOS infrastructure remediation.

All work must follow the master engineering rules:

```text
AUDIT
↓
define invariant
↓
RED
write/improve verification
↓
GREEN
minimum implementation
↓
REFACTOR
remove obsolete/duplicate configuration
↓
VERIFY
static + runtime validation
```

Do not jump directly into editing files.

Do not treat:

```bash
nix eval
```

as proof that the desktop actually works.

Configuration can evaluate successfully while still producing:

```text
wrong desktop IDs
wrong icons
broken MIME associations
broken PWA identity
blocked firewall traffic
broken Tailscale routing
broken SSH/tmux behavior
broken GNOME extension behavior
```

Static correctness and runtime correctness must be treated separately.

---

# 4. Host Scoping Rules

## Prague

Prague is the primary target and has these deliberate capabilities:

```text
GNOME workstation
Tailscale node
Tailscale exit node
remote administration endpoint
GNOME Remote Desktop endpoint
LocalSend endpoint
GitOps/control-plane workstation
```

### Prague Tailscale requirement

This is an architectural invariant:

```text
Tailscale MUST remain enabled on Prague.

Prague MUST remain connected to the tailnet.

Prague MUST advertise itself as an exit node.

Prague MUST remain capable of routing approved client traffic
to the Internet.

Prague's exit-node capability must survive reboot and ordinary
network transitions.
```

Do **not** disable Prague's exit-node capability merely to solve unrelated networking problems.

Do **not** migrate the working Tailscale ACL as part of this GNOME task.

The currently working ACL is the authoritative baseline.

---

## Tuscany

Tuscany may reuse GNOME modules, but must not accidentally inherit Prague-specific capabilities such as:

```text
exit-node functionality
Prague-specific network behavior
Prague-specific hardware configuration
Prague-only services
Prague-only secrets
```

Changes that affect Tuscany must be intentional and justified.

---

# 5. Repository Architecture

The repository uses modular NixOS/Home Manager configuration with automatic module discovery.

Inspect first:

```bash
pwd
git status --short --branch
git branch --show-current
git log -5 --oneline --decorate
```

Inspect automatic module discovery:

```bash
sed -n '1,240p' lib/auto-imports.nix
```

Respect the existing auto-import conventions.

Do not add manual imports for modules already discovered automatically.

Read relevant repository architectural guidance before modifying anything:

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

# 6. Engineering Classification Rules

Every significant finding must be classified as one of:

```text
CONFIRMED DEFECT
DESIGN RISK
INCOMPLETE IMPLEMENTATION
ASSUMPTION / REQUIRES RUNTIME VERIFICATION
```

Never present an assumption as a confirmed defect.

For each meaningful change record:

```text
reason
expected behavior
actual behavior
risk
test strategy
rollback/recovery implications
```

---

# 7. PHASE 0 — Repository and Desktop Architecture Audit

Before editing anything, build an inventory.

Run:

```bash
git status --short --branch
git branch --show-current
git log -5 --oneline --decorate
```

Then:

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

Networking audit:

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

Firefox PWA audit:

```bash
rg -n -i \
  'firefoxpwa|pwasforfirefox|programs\.firefoxpwa|firefox.*pwa|pwa.*firefox' \
  .
```

---

# 8. PHASE 1 — GNOME Visual Baseline

## Objective

Return the GNOME desktop to a consistent GNOME-native visual baseline.

Target:

```text
GTK theme   → GNOME/Adwaita
icons       → GNOME/Adwaita/default
cursor      → GNOME/Adwaita/default
```

Remove all remaining use of:

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
cursor-specific dconf overrides
XCURSOR_THEME
XCURSOR_SIZE
manual cursor overrides
```

where those settings only exist for the former Catppuccin cursor implementation.

Remove Tela as the system-wide GNOME icon theme:

```bash
rg -n -i 'tela|icon-theme'
```

Do not replace it with another third-party desktop-wide icon theme.

Audit overlapping ownership in:

```text
desktop/common/theme.nix
home/gnome/desktop.nix
home/theming.nix
dconf
environment variables
GTK configuration
```

There must be one deliberate owner for:

```text
GTK appearance
icon appearance
cursor appearance
```

## Verification

Run:

```bash
gsettings get org.gnome.desktop.interface gtk-theme
gsettings get org.gnome.desktop.interface icon-theme
gsettings get org.gnome.desktop.interface cursor-theme
gsettings get org.gnome.desktop.interface cursor-size
```

Exit criteria:

```text
no Catppuccin cursor configuration
no Tela desktop-wide icon theme
GNOME-native appearance is consistent
```

---

# 9. PHASE 2 — GNOME Application Foundation

## Objective

Make the base application layer coherent and GNOME-native.

Prefer:

```text
GNOME Console
Nautilus
GNOME Text Editor
```

Remove:

```text
gnome-terminal
```

if it exists solely as the terminal.

Remove:

```text
gnome-screenshot
```

completely.

Do not install a replacement screenshot application.

Preserve GNOME's built-in screenshot functionality.

Ensure required applications are supplied through the repository's normal package ownership model:

```text
Firefox
Microsoft Edge
LocalSend
Zed
LibreOffice
Notion
Apostrophe
Obsidian
Zoom
```

Do not unnecessarily duplicate packages between NixOS and Home Manager.

Scope Microsoft Edge appropriately to Prague unless Tuscany explicitly requires it.

---

# 10. Desktop Entry Identity

Never assume:

```text
package name == desktop file ID
```

Inspect the actual desktop environment:

```bash
find /run/current-system/sw/share/applications \
     -type f -name '*.desktop' | sort
```

and:

```bash
find ~/.local/share/applications \
     -type f -name '*.desktop' 2>/dev/null | sort
```

Validate relevant entries:

```bash
desktop-file-validate <desktop-file>
```

All configured launcher references must point to real desktop entries.

Do not invent application IDs.

---

# 11. PHASE 3 — GNOME Favorites

The required favorite list is exactly:

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

Microsoft 365 Edge PWAs:

```text
Outlook
Word
Excel
PowerPoint
Teams
OneDrive
```

must remain separate applications installed through Edge.

They are **not** part of the pinned Dock favorites unless the user explicitly chooses to add them later.

Do not pin:

```text
Evolution
GNOME Terminal
GNOME Console
Settings
PDF viewer
GNOME Screenshot
GNOME Software
Microsoft Edge browser
```

Do not hard-code unverified `.desktop` IDs.

Verify with:

```bash
gsettings get org.gnome.shell favorite-apps
```

---

# 12. PHASE 4 — Apostrophe and MIME Handling

Target:

```text
Markdown → Apostrophe
Plain text → GNOME Text Editor
```

Configure the appropriate MIME associations:

```text
text/markdown
text/x-markdown
text/plain
```

Discover the actual desktop IDs first.

Verify:

```bash
xdg-mime query default text/markdown
xdg-mime query default text/x-markdown
xdg-mime query default text/plain
```

Test representative files:

```text
README.md
architecture.md
notes.markdown
```

Markdown must open in Apostrophe.

Plain text must open in GNOME Text Editor.

---

# 13. PHASE 5 — Microsoft Edge PWA Architecture

## RESOLVED DESIGN DECISION

The Microsoft 365 PWA architecture is already decided.

Do not reopen the decision unless the pinned nixpkgs Edge package is technically incapable of implementing the requirements.

## Browser roles

### Firefox

Firefox remains the:

```text
primary general-purpose browser
```

Preserve all existing:

```text
profile data
bookmarks
extensions
Sidebery
enterprise policies
privacy settings
performance settings
Firefox persistence
```

Do not modify Firefox simply to support Microsoft 365 application launching.

### Microsoft Edge

Microsoft Edge is the:

```text
Microsoft 365 PWA runtime
```

It exists specifically to host:

```text
Outlook
Word
Excel
PowerPoint
Teams
OneDrive
```

---

# 14. Edge PWA Requirements

The implementation must result in six distinct applications.

Required applications:

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
unique application identity
unique launcher identity
unique desktop entry
correct application-specific icon
correct site
separate window/task-switcher identity
```

The six applications must not appear as:

```text
Microsoft Edge
generic browser
generic Edge app
generic browser icon
```

---

# 15. Edge PWA Installation Strategy

Use Edge's native PWA architecture.

Do not use:

```text
PWAsForFirefox
firefoxpwa
programs.firefoxpwa
Firefox wrapper scripts
firefox --new-window URL
```

Do not use bare:

```text
microsoft-edge --app=URL
```

as the final architecture merely to simulate independent applications.

The final architecture must preserve genuine application identity.

First verify Edge availability in the pinned nixpkgs:

```bash
nix eval --raw nixpkgs#microsoft-edge.version
```

and/or:

```bash
nix build nixpkgs#microsoft-edge --no-link
```

If the pinned nixpkgs revision lacks a functioning Edge package, update the appropriate pinned dependency rather than reverting to the rejected Firefox PWA architecture.

---

# 16. PWA Application Set

Required target URLs:

```text
Outlook    → https://outlook.office.com
Word       → https://www.office.com/launch/word
Excel      → https://www.office.com/launch/excel
PowerPoint → https://www.office.com/launch/powerpoint
Teams      → https://teams.microsoft.com
OneDrive   → https://onedrive.live.com
```

Verify the actual installed application URLs if Edge redirects them.

Do not hard-code incorrect URLs merely because they are common examples.

---

# 17. PWA Implementation Method

Choose the implementation that best fits the repository's architecture and the pinned Edge version.

Acceptable direction:

```text
native Edge PWA installation
+
Home Manager activation/provisioning
and/or
managed desktop entries
+
verified icons
+
verified StartupWMClass
```

Possible implementation approaches:

```text
Option A
Edge-native provisioning during first activation

Option B
declarative xdg.desktopEntries with correct Edge application invocation

Option C
hybrid Edge-native installation + declarative launcher management
```

The selected approach must be documented in the implementation before it is finalized.

Do not implement all six applications at once.

---

# 18. PWA RED/GREEN Strategy

Use Outlook as the initial proving case.

First create the verification.

Expected:

```text
Outlook launches
correct site loads
Outlook has its own launcher
Outlook has its own icon
Outlook has its own window identity
Outlook does not appear as generic Edge
```

Only after Outlook passes should the implementation be generalized to:

```text
Word
Excel
PowerPoint
Teams
OneDrive
```

---

# 19. PWA Desktop Entry Validation

For each installed PWA inspect:

```text
Name=
Exec=
Icon=
StartupWMClass=
```

Run:

```bash
desktop-file-validate <desktop-entry>
```

Validate that:

```text
Outlook → Outlook icon
Word → Word icon
Excel → Excel icon
PowerPoint → PowerPoint icon
Teams → Teams icon
OneDrive → OneDrive icon
```

Do not use the Edge browser icon as a substitute.

Where Edge generates the desktop entry, inspect the actual generated entry instead of creating a competing duplicate.

Avoid duplicate launchers.

---

# 20. PWA Runtime Validation

Launch every PWA individually.

Verify:

```text
correct application name
correct site
correct icon
correct launcher identity
correct task-switcher identity
separate Edge browser identity
session persistence
authentication persistence
```

Do not declare the PWA work complete because `.desktop` files merely exist.

---

# 21. PHASE 6 — LocalSend

## Objective

Provide reliable:

```text
Phone ↔ Prague
```

LocalSend communication on the local network without unnecessarily exposing the service through Tailscale or the public Internet.

Desired model:

```text
LAN
 ↓
LocalSend
 ↓
TCP/UDP 53317
```

Do not make LocalSend a Tailscale service merely for convenience.

---

# 22. LocalSend Firewall Architecture

The previous broad pattern:

```text
iifname != "tailscale0"
```

must not be interpreted as:

```text
LAN only
```

Audit the actual interfaces:

```bash
ip -br link
nmcli device status
ip -br addr
```

Then implement interface/network-scoped firewall behavior.

LocalSend should be reachable on the intended LAN interfaces only.

Do not expose TCP/UDP 53317 broadly to arbitrary WAN interfaces.

---

# 23. LocalSend Runtime Test

Inspect:

```bash
ss -lntup | grep 53317 || true
```

and:

```bash
sudo nft list ruleset
```

Then test actual:

```text
Phone → Prague
Prague → Phone
```

on the same LAN.

Verify:

```text
discovery
sending
receiving
```

all work.

---

# 24. PHASE 7 — Tailscale Architecture and Performance

## Important

The current working Tailscale ACL has been deliberately restored after an unsuccessful policy experiment.

**Do not alter the ACL as part of this task.**

The working policy remains authoritative.

The relevant design is:

```text
Phone
  │
  │ tag:user / existing ACL
  ▼
Tailscale
  │
  ▼
Prague
  │
  ├── Tailscale access
  └── exit-node routing
          │
          ▼
       Internet
```

---

# 25. Prague Exit-Node Invariants

The following must remain true:

```text
Tailscale enabled
tailscaled active
tailscale0 available
authentication persistent
Prague advertises exit-node capability
IP forwarding enabled
IPv6 forwarding enabled where required
NAT correct
firewall forwarding correct
network recovery works
```

Do not "fix" Tailscale performance by removing Prague's exit-node role.

---

# 26. Tailscale Diagnostic Process

Separate:

```text
ordinary Tailscale connectivity
```

from:

```text
exit-node Internet routing
```

Run:

```bash
tailscale status
tailscale netcheck
```

and:

```bash
tailscale ping <phone-device>
```

Determine whether the path is:

```text
direct
```

or:

```text
DERP / relay
```

Do not guess.

---

# 27. Exit-Node Test Separation

Test first:

```text
Phone
Tailscale ON
Exit Node = None
```

Verify:

```text
Tailscale connectivity
SSH to Prague
normal Tailscale latency
```

Then separately:

```text
Phone
Tailscale ON
Exit Node = Prague
```

Verify:

```text
Internet traffic routes through Prague
external public IP corresponds to Prague's egress path
DNS works
web browsing works
```

Do not attribute exit-node performance to ordinary Tailscale networking without evidence.

---

# 28. Tailscale Runtime Recovery

Test:

```text
cold boot
reboot
Wi-Fi reconnect
mobile hotspot transition
temporary network outage
sleep/resume
NetworkManager restart
tailscaled restart
```

Prague must recover its Tailscale gateway role without manual intervention under normal failure conditions.

---

# 29. PHASE 8 — GNOME Extensions

Final curated extension set:

```text
Dash to Dock
Tiling Assistant
Clipboard Indicator
Caffeine
Vitals
Just Perfection
```

Do not introduce unnecessary extensions.

Do not add:

```text
Blur My Shell
additional docks
additional launchers
additional clipboard managers
additional tiling systems
desktop widget frameworks
```

unless a concrete, tested requirement demands them.

The desktop must remain visibly and behaviorally GNOME-native.

Each extension must have a defined role:

```text
Dash to Dock
→ application/task workflow

Tiling Assistant
→ window organization

Clipboard Indicator
→ clipboard workflow

Caffeine
→ suspend inhibition

Vitals
→ system visibility

Just Perfection
→ GNOME Shell cleanup/customization
```

---

# 30. PHASE 9 — SSH + tmux Maintenance

## Objective

Provide reliable phone-based maintenance:

```text
Phone
 ↓
Tailscale
 ↓
SSH
 ↓
tmux
 ↓
maintenance
```

Use the repository's existing shell architecture.

Do not scatter SSH startup logic across unrelated shell modules.

---

# 31. tmux Requirements

Enable/configure:

```text
mouse
large history
reasonable escape timing
stable terminal
window numbering
pane numbering
persistent maintenance session
```

Required session name:

```text
maintenance
```

Interactive SSH should attach/create:

```bash
tmux new-session -A -s maintenance
```

or an equivalent implementation.

---

# 32. Interactive SSH Safety

Automatic tmux behavior must apply only to:

```text
interactive SSH sessions
```

It must NOT break:

```text
ssh host command
scp
sftp
automation
CI
Git operations
Nix commands
scripts
```

Use logic conceptually equivalent to:

```bash
if [[ -n "$SSH_TTY" && -z "$TMUX" && -o interactive ]]; then
    exec tmux new-session -A -s maintenance
fi
```

Integrate this with the actual shell framework.

Do not simply append duplicate shell startup logic.

---

# 33. SSH/tmux Tests

Test:

```bash
ssh ivali@prague
```

Expected:

```text
interactive shell → maintenance tmux
```

Then:

```bash
ssh ivali@prague 'echo hello'
```

Expected:

```text
command runs normally
no interactive tmux session created
```

Also verify network interruption/reconnection does not destroy the maintenance workflow unnecessarily.

---

# 34. PHASE 10 — GNOME Remote Desktop

Preserve the existing intended architecture:

```text
GNOME Remote Desktop
+
PAM authentication
+
Tailscale-only access
+
no public 3389
```

Do not reintroduce:

```text
KRDP
KDE remote desktop
public RDP
```

Audit for residue:

```bash
rg -n -i \
  'krdp|plasma.*remote|remote.*plasma|3389|xdg-desktop-portal-kde'
```

Do not open public RDP just to solve testing problems.

---

# 35. PHASE 11 — Firefox Preservation

Before touching Firefox configuration, read:

```text
FIREFOX-PERSISTENCE.md
```

Preserve:

```text
Firefox profile
bookmarks
cookies
extensions
Sidebery
enterprise policies
privacy configuration
performance settings
profile persistence
```

Do not use Firefox as the Microsoft 365 PWA runtime.

Remove obsolete Firefox PWA configuration only after confirming:

```text
Edge is the designated PWA runtime
Firefox profile remains intact
no existing non-PWA Firefox functionality depends on the removed configuration
```

Search for:

```bash
rg -n -i \
  'firefoxpwa|pwasforfirefox|programs\.firefoxpwa|firefox.*pwa|pwa.*firefox' \
  .
```

No residual Microsoft 365 Firefox PWA implementation should remain.

---

# 36. PHASE 12 — Cross-System Desktop Identity Audit

Inventory:

```bash
find /run/current-system/sw/share/applications \
     -type f -name '*.desktop' \
     -print | sort
```

and:

```bash
find ~/.local/share/applications \
     -type f -name '*.desktop' \
     -print | sort
```

Cross-check against:

```text
GNOME favorites
MIME associations
Edge PWAs
custom launchers
package declarations
```

Every launcher reference must point to a real entry.

No stale references may remain for:

```text
Evolution
GNOME Terminal
gnome-screenshot
old KDE applications
Firefox PWA launchers
old webapps
```

---

# 37. PHASE 13 — KDE Residue Audit

Search:

```bash
rg -n -i \
  'plasma|plasma6|kwin|kde|plasma-manager|krdp|sddm'
```

Classify each hit:

```text
active configuration
shared dependency
historical documentation
obsolete migration artifact
```

Remove only obsolete active configuration.

The runtime desktop must remain GNOME-only.

---

# 38. PHASE 14 — Cleanup

After behavior is correct, remove obsolete implementations instead of layering the new architecture over dead configuration.

Search for:

```text
Catppuccin cursor
Tela
gnome-screenshot
gnome-terminal
Evolution favorite
firefoxpwa
PWAsForFirefox
programs.firefoxpwa
fake Firefox webapps
stale KDE modules
duplicate MIME mappings
duplicate packages
broad LocalSend firewall rules
obsolete tmux/shell startup code
```

Use:

```bash
rg -n -i \
  'catppuccin.*cursor|cursor.*catppuccin|Tela-circle|tela-icon|gnome-screenshot|evolution\.desktop|firefoxpwa|pwasforfirefox|programs\.firefoxpwa' \
  .
```

Review every remaining match.

Nothing should remain solely because "it still builds."

---

# 39. PHASE 15 — Documentation

Update only the appropriate existing documentation owners.

Documentation must describe the actual implemented system:

```text
GNOME desktop architecture
Adwaita visual baseline
GNOME extension set
favorite application order
Markdown → Apostrophe
Firefox as primary browser
Microsoft Edge as Microsoft 365 PWA runtime
Edge PWA architecture
LocalSend LAN-only design
Tailscale remote administration
Prague permanent exit-node role
tmux maintenance architecture
GNOME Remote Desktop
```

Remove obsolete descriptions of:

```text
Catppuccin cursor
Tela desktop-wide icons
Firefox PWAs
PWAsForFirefox
firefoxpwa
Firefox webapp wrappers
KDE
KRDP
```

Do not create duplicate documentation where an existing document already owns the subject.

---

# 40. PHASE 16 — Static Validation

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

Where affected:

```bash
nix eval \
  .#nixosConfigurations.tuscany.config.system.build.toplevel.name
```

Then the repository-standard build/dry-build.

At minimum:

```bash
nix build \
  .#nixosConfigurations.prague.config.system.build.toplevel \
  --no-link
```

Use the repository's own deployment/build aliases when appropriate.

---

# 41. PHASE 17 — Existing Test Suite

Run:

```bash
go build ./...
go test ./...
go test ./internal/architecture/... -v
./ci/check-architecture
bash -n scripts/*.sh
```

Do not assume historical results remain valid after modifications.

---

# 42. PHASE 18 — GNOME Runtime Validation

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

Verify enabled extensions:

```bash
gnome-extensions list --enabled
```

Verify favorites:

```bash
gsettings get org.gnome.shell favorite-apps
```

Verify visual state:

```bash
gsettings get org.gnome.desktop.interface gtk-theme
gsettings get org.gnome.desktop.interface icon-theme
gsettings get org.gnome.desktop.interface cursor-theme
gsettings get org.gnome.desktop.interface cursor-size
```

---

# 43. PHASE 19 — MIME Validation

Run:

```bash
xdg-mime query default text/markdown
xdg-mime query default text/x-markdown
xdg-mime query default text/plain
xdg-mime query default inode/directory
xdg-mime query default application/pdf
```

Verify intended associations.

Especially:

```text
Markdown → Apostrophe
Plain text → GNOME Text Editor
Directories → Nautilus
```

where configured.

---

# 44. PHASE 20 — LocalSend Runtime Validation

Run:

```bash
ss -lntup | grep 53317 || true
```

Inspect:

```bash
sudo nft list ruleset
```

Then test actual phone ↔ Prague operation on the same LAN.

Do not claim success without verifying discovery and transfer.

---

# 45. PHASE 21 — Tailscale Runtime Validation

Run:

```bash
tailscale status
tailscale netcheck
```

Then:

```bash
tailscale ping <phone-device>
```

Record whether the path is:

```text
DIRECT
```

or:

```text
DERP / RELAY
```

Then independently validate:

```text
phone → Tailscale → Prague
```

and:

```text
phone → Prague exit node → Internet
```

Do not alter the ACL to make the test easier.

---

# 46. PHASE 22 — SSH/tmux Runtime Validation

From the phone:

```bash
ssh ivali@prague
```

Verify:

```text
interactive shell
→ maintenance tmux session
```

Then test:

```bash
ssh ivali@prague 'echo hello'
```

Verify:

```text
non-interactive command
→ normal execution
→ no unwanted tmux attach
```

---

# 47. PHASE 23 — Edge PWA Runtime Validation

Launch:

```text
Outlook
Word
Excel
PowerPoint
Teams
OneDrive
```

For every application verify:

```text
correct title
correct icon
correct launcher identity
correct window identity
correct site
not generic Edge
not generic browser
session persistence
```

Validate all relevant desktop files.

---

# 48. PHASE 24 — Final Visual Validation

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
consistent GNOME/Adwaita visual identity
correct icons
correct cursor
no missing assets
```

Then launch all six Microsoft 365 PWAs and verify:

```text
application-specific icons
separate application identities
correct launcher names
```

---

# 49. PHASE 25 — Security Review

Ensure the desktop remediation has not accidentally introduced:

```text
public SSH
public RDP
public LocalSend
unnecessary WAN ports
broad firewall rules
weakened Tailscale policy
weakened authentication
exposed browser services
unnecessary privileged launchers
```

Inspect:

```bash
sudo nft list ruleset
sudo ss -lntup
sudo ss -lnup
tailscale status
```

Every exposed service must have an intentional reason.

---

# 50. PHASE 26 — Final Repository Quality Gate

Run:

```bash
git diff --check
git status --short
git diff --stat
```

Then:

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

# 51. Required Validation Classification

Every final validation item must be classified as:

```text
STATICALLY VERIFIED
RUNTIME VERIFIED
REQUIRES USER/HARDWARE VERIFICATION
```

Examples:

```text
Nix module evaluates
→ STATICALLY VERIFIED

Desktop entry validates
→ STATICALLY VERIFIED

GNOME favorite list observed
→ RUNTIME VERIFIED

Phone actually receives a LocalSend file
→ RUNTIME VERIFIED

Phone routes Internet traffic through Prague
→ RUNTIME VERIFIED

Actual Wi-Fi sleep/resume behavior on physical hardware
→ REQUIRES USER/HARDWARE VERIFICATION
```

Never invent runtime results.

---

# 52. Final Architecture

The target Prague workstation is:

```text
                              PRAGUE
                                 │
                             GNOME/Wayland
                                 │
              ┌──────────────────┼──────────────────┐
              │                  │                  │
          Visual Layer       Applications       Remote Ops
              │                  │                  │
          Adwaita          Firefox              Tailscale
          GNOME icons      Edge                  SSH
          GNOME cursor     Microsoft 365         tmux
                           PWAs                  Gnome RDP
              │
       ┌──────┴───────┐
       │              │
    Extensions     Favorites
       │              │
 Dash to Dock      Firefox
 Tiling Assistant  Nautilus
 Clipboard         LocalSend
 Caffeine          Zed
 Vitals            LibreOffice
 Just Perfection   Notion
                   Text Editor
                   Apostrophe
                   Obsidian
                   Zoom

Microsoft Edge
 ├── Outlook
 ├── Word
 ├── Excel
 ├── PowerPoint
 ├── Teams
 └── OneDrive

Network
 ├── LAN → LocalSend
 ├── Tailscale → administration
 └── Prague → permanent exit node
                 │
                 ▼
              Internet
```

---

# 53. Final Success Definition

The task is complete only when all of the following are true:

```text
Prague boots into GNOME/Wayland through GDM.

GNOME uses its native visual baseline.

No Catppuccin cursor implementation remains.

No Tela desktop-wide icon implementation remains.

The separate screenshot package is gone.

The GNOME Dock contains exactly the requested ten applications.

Markdown opens in Apostrophe.

Plain text opens in GNOME Text Editor.

LocalSend works over the local LAN.

LocalSend is not unnecessarily exposed through Tailscale/WAN paths.

Tailscale remains enabled on Prague.

Prague remains an exit node.

The existing working Tailscale ACL remains intact.

Tailscale connectivity has been empirically diagnosed.

Exit-node routing has been tested separately from ordinary Tailscale connectivity.

The phone can use Prague as its exit node.

Interactive SSH sessions automatically enter the "maintenance" tmux session.

Non-interactive SSH remains unaffected.

GNOME Remote Desktop remains Tailscale-protected and not publicly exposed.

Firefox remains the primary general-purpose browser and its profile remains intact.

Microsoft Edge is the dedicated Microsoft 365 PWA runtime.

Outlook, Word, Excel, PowerPoint, Teams and OneDrive exist as distinct applications.

Each Microsoft 365 PWA has its own icon and application identity.

No Firefox PWA/PWAsForFirefox/firefoxpwa implementation remains.

No stale KDE configuration remains active.

The configuration remains declarative.

Host scoping is correct.

Static checks pass.

Relevant runtime checks pass.

Unverifiable hardware-dependent items are explicitly identified.

The repository remains architecturally coherent.
```

---

# 54. Final Deliverable

At completion, provide:

## Changed Files

For every changed file:

```text
path
purpose
key change
host scope
```

## Removed Configuration

Explicitly identify removed:

```text
Catppuccin cursor
Tela icon theme
gnome-screenshot
gnome-terminal
Evolution favorites/references
firefoxpwa
PWAsForFirefox
programs.firefoxpwa
fake Firefox webapps
obsolete KDE configuration
duplicate MIME handlers
broad LocalSend firewall rules
obsolete shell startup code
```

## Added Configuration

Explicitly identify:

```text
Microsoft Edge
Apostrophe
Tiling Assistant
favorites
Edge PWA architecture
LocalSend firewall behavior
tmux maintenance behavior
GNOME-native visual defaults
```

## Test Results

Report actual outcomes for:

```text
Nix formatting
flake validation
host evaluation
host build
Go tests
architecture checks
GNOME runtime
MIME associations
LocalSend
Tailscale
SSH/tmux
Edge PWAs
desktop entry validation
```

## Remaining Risks

For every unresolved issue:

```text
problem
evidence
impact
what was attempted
why unresolved
next diagnostic/action
```

Never claim a runtime behavior was verified when it was not actually observed.

---

# 55. Operating Principle

Do not optimize for the number of Nix files changed.

Optimize for:

```text
correctness
security
clarity
reproducibility
least privilege
observability
recoverability
GNOME-native user experience
```

The final workstation should be **boring in the best possible way**:

```text
GNOME behaves like GNOME.
Applications identify themselves correctly.
The phone reaches Prague securely.
Prague remains the trusted exit gateway.
LocalSend works on the LAN.
SSH drops into persistent maintenance.
Microsoft 365 applications behave like separate desktop apps.
The configuration remains declarative.
The system is tested rather than assumed.
```

That is the definition of done.

---

# Session Handoff — Syncthing GUI Credentials & Firewall Hardening

Recorded: 2026-09-28 · Branch merged to `main` at `951aca0` · Host: prague

## 1. What Changed

| # | Change | MR | State |
|---|---|---|---|
| 1 | Stale LocalSend firewall assertions replaced with default-deny guards | !87 | MERGED |
| 2 | Docker container runtime enabled on prague | !88 | MERGED |
| 3 | Syncthing GUI credentials via SOPS + tailnet-only firewall | !89 | MERGED |

All three pipelines green. MR !89: 13/13 jobs success.

## 2. Syncthing Credential Source of Truth

The declarative chain, which now carries the requested credentials:

```text
GUI username:  ivali
  ← services.syncthing.settings.gui.user        (hosts/prague.nix)

GUI password:  (rotated to the operator-specified value)
  ← secrets/syncthing.yaml
  ← sops.secrets.syncthing_gui_password   owner ivali, mode 0400
  ← /run/secrets/syncthing_gui_password
  ← services.syncthing.guiPasswordFile
  ← syncthing-init.service
      mkpasswd -m bcrypt --stdin  →  PATCH /rest/config/gui {"password": "<bcrypt>"}
```

`syncthing-init.service` re-applies username, TLS, and the bcrypt-hashed password
on every boot, so the GUI cannot drift from the repository.

`.sops.yaml` requires no change: its `secrets/.*\.yaml$` creation rule already maps
`secrets/syncthing.yaml` to recipient `age1ps5ptf…s7h`, the same key used by every
other secret in the repository.

## 3. Firewall

`openDefaultPorts` was `true`, which opened `22000/tcp` and `22000 + 21027/udp` on
**every** interface. Now `false`. The `tailscale0` block is the sole inbound path:

```text
tailscale0   TCP 22 53 80 443 3389 8384 22000
             UDP 53 22000
global       TCP 22
             UDP 3478 5353 41641
```

The phone syncs over the tailnet, so this is a tightening, not a capability removal.

## 4. Critical Operational Note

`syncthing-init.service` is `Type=oneshot` with `RemainAfterExit=true`.

> **A `systemctl daemon-reload` alone will NOT re-run it.**
> The new password is not applied until `systemctl restart syncthing-init.service`.

### Post-activation verification (not yet performed)

```bash
systemctl restart syncthing-init.service

# positive control — must return 200
curl -s -o /dev/null -w '%{http_code}\n' -u 'ivali:<pw>' -k \
  https://100.81.219.121:8384/rest/system/status

# negative control — the previous password must return 401
curl -s -o /dev/null -w '%{http_code}\n' -u 'ivali:<old-pw>' -k \
  https://100.81.219.121:8384/rest/system/status

# confirm the hash is bcrypt and the user is ivali
curl -s -u 'ivali:<pw>' -k https://100.81.219.121:8384/rest/config/gui \
  | jq '{user, tlsEnabled, hash: (.password[0:4])}'

# secret file must be 4 bytes, 0400
stat -c '%s %a %U' /run/secrets/syncthing_gui_password

# 22000 must appear only under tailscale0
nft list ruleset | grep -n 22000
```

**This has not been executed.** It requires the GitOps reconciler to activate a
generation containing `951aca0`. Runtime health is therefore UNVERIFIED.

## 5. Dead Code / Drift Found (Not Fixed)

Recorded rather than silently expanded into scope.

| Finding | Detail |
|---|---|
| `dataDir` is a no-op | `services.syncthing.dataDir` is set to `/home/ivali/.local/share/syncthing`, but the module passes `--data=${databaseDir}`, which defaults to `configDir`. That directory has never existed. Either drop the option or set `databaseDir` deliberately. |
| `listenAddresses` binds all interfaces | `tcp://0.0.0.0:22000` remains. The firewall is now the sole control point, which is correct, but binding is broader than necessary. |
| `overrideFolders` / `overrideDevices` are `false` | GUI-side folder and device edits are never reconciled. A folder deleted in the GUI silently reappears on the next `syncthing-init` run. This is the main declarative-drift surface. |
| `guiAddress` hardcodes a tailnet IP | `100.81.219.121:8384`. If the tailnet IP changes, GUI binding breaks **and** `merge-syncthing-config` blocks indefinitely in its `xmllint`/curl retry loop. A `unix://` socket plus reverse proxy is the resilient alternative. |
| No `services/syncthing/` domain module | Config is inline in `hosts/prague.nix`, unlike nginx/postgres/redis/blocky which use `ivali.services.<name>.enable`. Extracting one would let eval assertions live with the capability. |
| `services/blocky/` missing from architecture model | `architecture/domains.yaml` `runtime.services.internal` omits it. Pre-existing gap, unrelated to syncthing. |
| Syncthing is undocumented | Before MR !87, syncthing appeared in **zero** documentation files. `security/README.md` was corrected as part of the LocalSend fix; `MODULES.md`, `ARCHITECTURE.md`, and `docs/*` still do not describe it. |
| `.stfolder/` and `.stignore` untracked | Runtime artifacts of the `nixos-config` sync folder. Not gitignored, so `git status` always shows them. |

## 6. Security Notes

- The GUI password is a 4-character dictionary word, at the operator's explicit
  instruction. Exposure is bounded: the GUI binds to the tailnet address and
  `8384` is opened on `tailscale0` only. Anyone on the tailnet who guesses it
  gains Syncthing's REST API, which grants filesystem control. Recommend rotating
  to a passphrase as follow-up.
- No plaintext secret exists in the repository. The `secrets/syncthing.yaml` diff is
  ciphertext-only (`data`, `mac`, `lastmodified`). `gitleaks` passed in CI.
- The value was passed to `sops set` via a temporary file under `/tmp/opencode`,
  which was deleted. The old password remains in git history as ciphertext only.

## 7. Repository State

```text
branch:   main, identical to origin/main
HEAD:     951aca0 Merge branch 'security/syncthing-gui-credentials' into 'main'
tree:     clean, except untracked .stfolder/ and .stignore (syncthing runtime artifacts)
```

Gates verified locally before each push: `nix fmt --check`, `nix flake check --no-build`,
`nix eval .#nixosConfigurations.prague…toplevel.name`, `go build`, `go vet`,
`go test -race -count=1`, `check-architecture`.

## 8. Next Exact Action

1. Confirm the GitOps reconciler has activated a generation containing `951aca0`.
2. `systemctl restart syncthing-init.service` — required, see §4.
3. Run the verification block in §4 and confirm 200 / 401 / bcrypt / 4 bytes.
4. Confirm the phone still syncs `documents` and `sync` over the tailnet.
5. Optional follow-ups from §5, in priority order: rotate the GUI password to a
   passphrase; add a `services/syncthing/` module with eval assertions; document
   syncthing in `MODULES.md` and `ARCHITECTURE.md`.

## 9. Relevant Documents

For the next agent continuing this work:

```text
AGENTS.md                  AI operating contract — mandatory
IVALI_FLOW.md              Git lifecycle; CI failure handling
secrets/syncthing.yaml     GUI password (SOPS ciphertext)
lib/host-templates/laptop.nix:54-58    secret declaration
lib/host-templates/laptop.nix:282-283  guiPasswordFile wiring
hosts/prague.nix:63-155     syncthing service + firewall
security/README.md         port inventory (corrected in !87)
tests/security-smoke.nix   firewall default-deny tests
```

# Session Handoff — GitLab Host Token Self-Rotation

## 1. What Changed

The host no longer depends on a manually-rotated GitLab personal access
token. A scheduled service rotates the dedicated **host** token before it
expires and re-materialises it through SOPS.

Merged:

```text
!93  security: store rotated gitlab runner api token in sops
!94  fix: add missing shebang to diagnostic.sh
!95  fix: fix collabora-desktop coda-qt link error
!96  fix: extend anyio test quarantine to python313/314
!97  feat: add self-rotating gitlab host token      (prague infra)
```

## 2. Rotation Design

```text
systemd timer (daily)
   ↓
gitlab-token-rotate.sh
   ↓
GET /personal_access_tokens/self   → expires_at
   ↓  (only if <= dropDaysBefore days left)
POST /personal_access_tokens/self/rotate?expires_at=+newTtlDays
   ↓
re-encrypt secrets/gitlab.yaml in a DEDICATED worktree
   ↓
commit + push to main
   ↓
trigger gitops-reconciler.service → rebuild → new /run/secrets/gitlab_token
```

Ownership:

```text
fleet.gitlabTokenRotate.{enable,schedule,dropDaysBefore,newTtlDays}
systemd gitlab-token-rotate.{service,timer}
automation/gitlab-token-rotate.nix
scripts/gitlab-token-rotate.sh
tests/gitlab-token-rotate-smoke.nix
```

Defaults: rotate when `<= 7` days remain, new expiry `+30` days.

Key constraint: the reconciler uses `REPO_DIR=/var/lib/gitops`. If the
rotation service committed into that checkout the reconciler would see
`local == remote` and **skip the deploy**, so rotation uses a separate
worktree under its `StateDirectory`.

## 3. Operational Notes

- The host token must carry the `api` (or `self_rotate`) scope.
- GitLab.com restricts `POST /user/personal_access_tokens` (self) to the
  `k8s_proxy` scope, so a *new general* PAT cannot be created via API.
  Only rotating an existing token works via API, which is what this does.
- The current sops token expires 2026-11-16 (~30 days out), so the first
  scheduled runs are no-ops (`days_left > 7`). Safe to deploy immediately.
- Token separation: this is the **host** token, distinct from the
  operator's `glab` CLI token. See section 5 for the pending step.

## 4. Temporary Cleanup Done

All temporary token material (`/tmp/opencode/.glpat*`, the decrypted SOPS
worktree, mock-API artifacts) was shredded/removed. No plaintext token
remains on the host outside `/run/secrets/`.

## 5. Latent Bug Fixed

`automation/channel-bump.nix` declared `sops.secrets.gitlab_api_token`,
but `secrets/gitlab.yaml` only contains `gitlab_token`. The module was
never enabled, so it was dormant. Corrected to `gitlab_token` (also fixed
in the regenerated `DOCS.md`).

## 6. Documentation Drift Found (Not Fixed)

`DOCS.md` is stale relative to reality (generated header says
`201 documented modules`; a full `ivali docs` regeneration yields `205`
plus unrelated gruvbox→mokka theme text). Only the rotation module section
and the channel-bump fix were hand-applied to keep MR !97 minimal. A
dedicated `docs:` regeneration MR is the correct follow-up.

## 7. Collabora Overlay

`lib/overlays/collabora-desktop.nix` (+ patch
`patches/collabora-desktop/0002-fix-coda-qt-link.patch`) is a temporary
workaround. Remove it once the pinned nixpkgs is at/after upstream commit
`c2342c171205`.

## 8. Next Exact Action

1. Operator: create a **new** glab CLI token in the GitLab UI
   (scopes `api`, `write_repository`; name e.g. `glab-cli`).
2. Paste it to the agent so glab can be moved off the host token:

   ```bash
   glab auth login --hostname gitlab.com --token <new-glab-token>
   ```

3. Verify: `glab auth status` and confirm the host token is no longer
   used interactively.
4. Confirm the next `gitops-reconciler` run enables
   `gitlab-token-rotate.timer` on prague.

## 9. Repository State

```text
branch: main (feature/gitlab-host-token-self-rotation merged as !97)
last:   Merge branch 'feature/gitlab-host-token-self-rotation' into 'main'
```

## 10. Relevant Documents

```text
AGENTS.md                          AI operating contract — mandatory
IVALI_FLOW.md                      Git lifecycle; CI failure handling
automation/gitlab-token-rotate.nix rotation module
scripts/gitlab-token-rotate.sh     rotation logic
tests/gitlab-token-rotate-smoke.nix nixosTest (mock GitLab API)
secrets/gitlab.yaml                encrypted host token (gitlab_token)
automation/channel-bump.nix        corrected to gitlab_token
automation/channel-bump.nix:52-57  secret declaration
DOCS.md                            module docs (stale — see 4b)
```
