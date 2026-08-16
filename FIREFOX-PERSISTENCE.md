# Firefox Persistence Architecture

Production-grade, declarative Firefox profile for the `prague` host. This
document explains how the `ivali` Firefox profile is managed, what was tried,
what was fixed, and how to recover from disaster.

---

## 1. Goals

* Firefox profile **data** (logins, cookies, Firefox Account session, history,
  extension state, local storage) persists across NixOS rebuilds and is backed
  up together with the user's home.
* Profile data lives in a **plain directory** at
  `~/.mozilla/firefox/ivali` on the `/home` Btrfs subvolume (no dedicated
  profile subvolume — that design was tried and dropped, see §2).
* **Configuration** (profile definition, extensions, preferences, UI) is fully
  declarative via Home Manager and reproducible from a fresh clone.
* Firefox **never** creates or prefers a transient default profile outside the
  managed one.
* All extensions are installed declaratively and auto-enabled on first launch.
* Reproducible end-to-end: `git clone` → `nixos-rebuild switch --flake .#prague`.

---

## 2. Architecture

```
NixOS flake
└── home/firefox/default.nix        ← programs.firefox (Home Manager)
      ├─ configPath = ".mozilla/firefox"        (where nixpkgs Firefox reads)
      ├─ profiles.ivali.path = "ivali"          (RELATIVE, plain directory)
      ├─ addons (mkAddon)                      (4 declarative add-ons)
      ├─ profiles.ivali.settings                (privacy/perf/session prefs)
      └─ profiles.ivali.userChrome              (Gruvbox-dark, compact)
```

### Data flow

* **Declarative config** (`profiles.ini`, `user.js`, `chrome/userChrome.css`)
  is written by Home Manager into the Firefox config dir
  (`~/.mozilla/firefox`), which is a normal directory on the user's home
  subvolume.
* The `ivali` **profile directory** (`~/.mozilla/firefox/ivali`) is a **plain
  directory** on the `/home` subvolume. Everything Firefox writes there
  (cookies, `key4.db`, `logins.json`, `signedInUser.json`, `places.sqlite`,
  extension state) persists across rebuilds and is covered by whatever backup
  strategy protects `/home`.
* Extensions are installed by Home Manager into
  `<profile>/extensions/<gecko-id>.xpi` and enabled via
  `extensions.autoDisableScopes = 0`.

### Why a plain directory (not a dedicated subvolume)

An earlier iteration declared a sibling `firefox-ivali` Btrfs subvolume mounted
at `~/.mozilla/firefox/ivali`, on the theory that profile data would survive a
full reinstall. That design was **dropped** because it was not supportable on
the live host: the subvolume and its mount/oneshot service were baked into
`hardware-configuration.nix` with a phantom disk UUID that does not exist on
this machine, which caused the filesystem-mount failure that put the host into
emergency mode during a switch. The plain-directory layout is the reality on
disk and is what this configuration declares.

Profile data therefore survives upgrades and rollbacks, and should be backed
up as part of `/home`. Reinstalls that wipe `/home` will also wipe the profile
data — restore it from backup.

---

## 3. The original bugs (and why they broke persistence)

### Bug 1 — Wrong Firefox configuration directory
Home Manager, in that nixpkgs/HM combination, defaulted Firefox's config path
to `~/.config/mozilla/firefox`, but the nixpkgs Firefox binary reads/writes
profiles from `~/.mozilla/firefox`. Result: HM built the `ivali` profile in a
directory Firefox never looked at, and Firefox created its own default profile
in `~/.mozilla/firefox`, completely bypassing the managed profile.

**Fix:** `configPath = ".mozilla/firefox"`.

### Bug 2 — Invalid absolute profile path
The profile was configured with an absolute path
`/home/ivali/.mozilla/firefox/ivali`. HM then emitted:

```ini
Path=/home/ivali/.mozilla/firefox/ivali
IsRelative=1
```

`IsRelative=1` requires `Path` to be relative to the Firefox config dir, so
Firefox could not resolve it, dropped the `ivali` entry, rewrote
`profiles.ini`, and reverted to its own auto-created default.

**Fix:** `path = "ivali"` → valid `Path=ivali` with `IsRelative=1`.

### Bug 3 — Wrong extension installation layout (two attempts)

The original config tried to install extensions via `home.file` symlinks
(`.mozilla/firefox/ivali/extensions/nixos@<name>.xpi`) pointing into the Nix
store. Firefox refused to stage a symlink to a read-only store path, deleted
the drop-ins, and never registered the add-ons — only uBlock Origin ever
appeared, inconsistently.

A second attempt used Home Manager's `profiles.ivali.extensions.packages`.
That mechanism copies each add-on into `<profile>/extensions/<gecko-id>.xpi`
(real files), which looks correct — but **modern Firefox no longer
auto-installs add-ons dropped into `<profile>/extensions/`**. The legacy
"sideload" folder was removed; Firefox simply ignores those files.

An intermediate design also documented **Firefox Policies**
(`policies.ExtensionSettings`) as the install mechanism. That was a
documentation-only claim: the actual module never shipped policies, and
Policies were abandoned for the mechanism below.

**Fix (current):** `pkgs.fetchFirefoxAddon` + a **direct xpi drop-in**. Each
add-on is fetched once by nixpkgs (`fetchFirefoxAddon { name; url; sha256 }`),
which pins the exact AMO `latest.xpi` in the Nix store and re-writes the
add-on's Gecko id to `nixos@<name>`. Home Manager then copies
`<store>/<gecko-id>.xpi` as a **real file** (via `force = true`) into
`<profile>/extensions/`, and Firefox loads any `<gecko-id>.xpi` whose filename
matches the id inside the xpi. No symlinks, no Policies, no sideload guessing.

---

## 4. Applied fixes (current generation)

1. `configPath = ".mozilla/firefox"` — HM writes where Firefox reads.
2. `path = "ivali"` — valid relative profile path → plain dir under
   `~/.mozilla/firefox`.
3. `mkAddon` + `fetchFirefoxAddon` — pinned AMO xpis copied verbatim into
   `<profile>/extensions/<gecko-id>.xpi` (real files, `force = true`).
4. `extensions.autoDisableScopes = 0` — any add-on present is enabled rather
   than installed-but-disabled.
5. Session persistence prefs (see §6).
6. The sidebar hosts **Sidebery** as the tab tree (see §7).

### Installed extensions (declarative, via fetchFirefoxAddon)

| Add-on | Gecko id after fetch (`nixos@<name>`) | AMO install_url |
|---|---|---|
| uBlock Origin | `nixos@ublock-origin` | `…/latest/ublock-origin/latest.xpi` |
| Bitwarden | `nixos@bitwarden-password-manager` | `…/latest/bitwarden-password-manager/latest.xpi` |
| Dark Reader | `nixos@darkreader` | `…/latest/darkreader/latest.xpi` |
| Sidebery | `nixos@sidebery` | `…/latest/sidebery/latest.xpi` |

`fetchFirefoxAddon` derives the id from the xpi's own `install.rdf`/`manifest.json`
and exposes it as `pkg.extid`; Home Manager names the dropped-in file with that
exact id, which is what Firefox matches when loading `<profile>/extensions/`.

### UI customization

* Gruvbox-dark theme + compact density via `userChrome.css`.
* `browser.uidensity = 1` (compact), `ui.systemUsesDarkTheme = 1`.
* **Native sidebar as container + Sidebery tab tree**: `sidebar.revamp` +
  `sidebar.verticalTabs = true` + `sidebar.visibility = "always-show"` keeps
  the native sidebar permanently expanded; `userChrome.css` hides the launcher
  rail (`#sidebar-main`, `#sidebar-launcher-splitter`) so the Sidebery panel
  fills the sidebar, and `sidebery-default-open.js` (autoconfig bootstrap)
  re-opens Sidebery after session restore. Tab layout (tree state, pinned set)
  is Sidebery state and persists in the `ivali` profile directory.

---

## 5. profiles.ini correctness

Home Manager generates `~/.mozilla/firefox/profiles.ini` containing:

```ini
[General]
StartWithLastProfile=1
Version=2

[Profile0]
Default=1
IsRelative=1
Name=ivali
Path=ivali
```

Verification:

```bash
grep -E '^(Name|Path|Default|IsRelative)=' ~/.mozilla/firefox/profiles.ini
# expect: Name=ivali  Path=ivali  Default=1  IsRelative=1
```

> Note: `profiles.ini` is managed by Home Manager as a symlink to the Nix
> store. Firefox cannot rewrite a read-only symlink target, but with
> `StartWithLastProfile=1` + `Default=1` it launches `ivali` correctly. If
> Firefox ever adds a secondary `*.default` entry, see §9.2.

---

## 6. Session persistence settings

```nix
"network.cookie.cookieBehavior"        = 1;  # block 3rd-party, keep 1st-party
"network.cookie.lifetimePolicy"        = 0;  # keep cookies until expiry
"privacy.sanitize.sanitizeOnShutdown"  = false;  # DO NOT wipe on exit
"signon.rememberSignons"               = true;
"signon.management.overlay.enabled"    = true;
```

These ensure cookies, logins, and the Firefox Account session
(`signedInUser.json`) persist. All of these files live in the `ivali` profile
directory on the `/home` subvolume.

---

## 7. Sidebery tab tree usage

The native sidebar (`sidebar.revamp` = true, `sidebar.verticalTabs` = true)
acts as the container; **Sidebery** owns the tabs and renders a tree inside
it. `sidebar.visibility = "always-show"` keeps the sidebar permanently
expanded, and `userChrome.css` hides the launcher rail so the Sidebery panel
fills the sidebar edge-to-edge.

**Everyday use**
- The sidebar is always visible on the left, showing the full Sidebery tab
  tree. There is no collapsed rail and nothing expands on hover.
- The panel header (sidebar-switcher-target) still drops down to switch to
  other extensions in the sidebar.
- Sidebery's own UI (tabs on top, panels on the right of the tree) is themed
  dark to match Gruvbox; its settings are stored in the `ivali` profile
  (`storage`) and persist across rebuilds.
- Open a link with middle-click / Ctrl+click → new **background** tab (no focus
  theft, per the browsing prefs).
- Sidebery tree state (tabs, panels, bookmarks view) persists in the `ivali`
  profile directory across restarts and rebuilds.
- Window chrome (Gruvbox-dark) is themed via `userChrome.css`.

**Customization (declarative, in `home/firefox/default.nix`)**
- `sidebar.verticalTabs = true` — Firefox relocates its native tab strip into
  the launcher rail; `#sidebar-main { display: none }` hides both.
- `sidebar.visibility = "always-show"` — full sidebar always open (native
  `"expand-on-hover"` and `"hide-sidebar"` collapse it).
- `#sidebar-main, #sidebar-launcher-splitter { display: none !important; }` —
  removes the launcher rail so only the Sidebery panel shows.
- `sidebery-default-open.js` — per-window bootstrap (injected via
  mozilla.cfg) that re-opens Sidebery after session restore races and reapplies
  a closed panel. It respects a different restored sidebar and stops polling
  once the panel is open and UI state settled.

---

## 8. Verification checklist (run after every reinstall)

- [ ] `~/.mozilla/firefox/profiles.ini` → `Name=ivali`, `Path=ivali`,
      `Default=1`, `IsRelative=1`.
- [ ] Firefox shows uBlock Origin, Bitwarden, Dark Reader, Sidebery as
      enabled in `about:addons` → Extensions.
- [ ] `~/.mozilla/firefox/ivali/extensions/` contains the four
      `nixos@<name>.xpi` files (real files, not symlinks into the store).
- [ ] Gruvbox-dark theme + compact density applied (about:preferences →
      "Density: Compact"; native sidebar permanently visible, Sidebery tab
      tree fills it with no launcher rail).
- [ ] Sign into a test site + Firefox Account, then `nixos-rebuild switch`;
      session + FxA stay signed in.
- [ ] No `*.default` profile appears under `~/.mozilla/firefox/`.

---

## 9. Disaster recovery

### 9.1 If the profile directory is lost or corrupted

1. The declarative config restores extensions, UI, and preferences
   automatically on the next switch — only **user data** (cookies/logins/FxA)
   is lost, because that lives only in the profile directory.
2. Re-sign into sites and the Firefox Account. Consider enabling Firefox
   Sync as a secondary backup for critical credentials.

### 9.2 If Firefox creates a transient default profile

1. Close Firefox.
2. Inspect: `cat ~/.mozilla/firefox/profiles.ini`.
3. If a `*.default` entry appears, `configPath`/`path` likely drifted in
   `home/firefox/default.nix`. Fix the module, re-run `nixos-rebuild switch`,
   then:
   ```bash
   rm -rf ~/.mozilla/firefox/*.default
   ```
   and confirm `profiles.ini` again references only `ivali`.

### 9.3 If an extension hash fails to fetch

`fetchFirefoxAddon` hashes are pinned in the `addons` set in
`home/firefox/default.nix`. AMO occasionally rebuilds an `latest.xpi`, which
changes the hash and fails the build. Resolve the new hash with:

```bash
nix-prefetch-url https://addons.mozilla.org/firefox/downloads/latest/sidebery/latest.xpi
```

Update the corresponding `sha256` and rebuild.

---

## 10. Production readiness summary

**Ready.** The declarative config, profile wiring, extension installation,
UI customization, session-persistence prefs, and the Sidebery sidebar setup
are all in place. Real-world verification is a `nixos-rebuild switch` on the
live host followed by confirming all four extensions are enabled and a
re-login test survives a rebuild — see §8.
