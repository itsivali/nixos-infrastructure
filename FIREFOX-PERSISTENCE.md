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
* All three extensions are installed declaratively and auto-enabled on first
  launch.
* Reproducible end-to-end: `git clone` → `nixos-rebuild switch --flake .#prague`.

---

## 2. Architecture

```
NixOS flake
└── home/firefox/default.nix        ← programs.firefox (Home Manager)
      ├─ configPath = ".mozilla/firefox"        (where nixpkgs Firefox reads)
      ├─ profiles.ivali.path = "ivali"          (RELATIVE, plain directory)
      ├─ profiles.ivali.extensions.packages     (3 declarative add-ons)
      ├─ profiles.ivali.settings                (privacy/perf/session prefs)
      └─ profiles.ivali.userChrome              (Gruvbox-dark, compact, native vertical tabs)
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

## 3. The three original bugs (and why they broke persistence)

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

### Bug 3 — Incorrect extension installation layout
The original config tried to install extensions via `home.file` symlinks
(`.mozilla/firefox/ivali/extensions/nixos@<name>.xpi`) pointing into the Nix
store. Firefox refused to stage a symlink to a read-only store path, deleted
the drop-ins, and never registered the add-ons — only uBlock Origin ever
appeared, inconsistently.

A second attempt used Home Manager's `profiles.ivali.extensions.packages`.
That mechanism copies each add-on into `<profile>/extensions/<gecko-id>.xpi`
(real files), which looks correct — but **modern Firefox no longer
auto-installs add-ons dropped into `<profile>/extensions/`**. The legacy
"sideload" folder was removed; Firefox simply ignores those files. Verified
empirically: a fresh profile with the four xpis present in `extensions/`
launched and registered **none** of them.

**Fix:** install via **Firefox Policies** (`policies.ExtensionSettings`). This
is the only mechanism current Firefox honours for unattended, reproducible
extension install. Each entry keys on the add-on's real Gecko id and sets
`installation_mode = "force_installed"` with an `install_url` pointing at the
AMO download. On first launch Firefox fetches and installs each add-on and
keeps it installed (and updated) thereafter.

---

## 4. Applied fixes (current generation)

1. `configPath = ".mozilla/firefox"` — HM writes where Firefox reads.
2. `path = "ivali"` — valid relative profile path → plain dir under
   `~/.mozilla/firefox`.
3. `policies.ExtensionSettings` — declarative, force-installed from AMO via
   Firefox Policies (the only mechanism modern Firefox honours).
4. `extensions.autoDisableScopes = 0` — belt-and-braces so any add-on added by
   other means is enabled rather than installed-but-disabled.
5. Session persistence prefs (see §6).
6. Build-time assertions (see §7) and runtime guards (stale-profile removal +
   regression detection) in `home/firefox/default.nix`.

### Installed extensions (declarative, via policy)

| Add-on | Real Gecko id (policy key) | AMO install_url |
|---|---|---|
| uBlock Origin | `uBlock0@raymondhill.net` | `…/latest/ublock-origin/latest.xpi` |
| Bitwarden | `{446900e4-71c2-419f-a6a7-df9c091e268b}` | `…/latest/bitwarden-password-manager/latest.xpi` |
| Dark Reader | `addon@darkreader.org` | `…/latest/darkreader/latest.xpi` |

These are the upstream Gecko ids (verified from each add-on's `manifest.json`),
keyed exactly as Firefox expects in `ExtensionSettings`.

### UI customization

* Gruvbox-dark theme + compact density via `userChrome.css`.
* `browser.uidensity = 1` (compact), `ui.systemUsesDarkTheme = 1`.
* **Native vertical tabs** (`sidebar.revamp` + `sidebar.verticalTabs`): the tab
  strip lives in the sidebar, replacing the horizontal strip (no extension
  needed). `sidebar.visibility = "expand-on-hover"` keeps the sidebar collapsed
  to a slim icon rail showing pinned-tab favicons, expanding to full tabs on
  hover; pinned tabs stay visible as icons at the top of the rail. The
  Gruvbox-dark chrome is themed from `userChrome.css`. Tab layout (pinned set,
  collapse state) is Firefox state and persists normally in the `ivali`
  profile directory.

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
> `StartWithLastProfile=1` + `Default=1` it launches `ivali` correctly. The
> runtime guard in `home/firefox/default.nix` warns if Firefox ever adds a
> secondary `*.default` entry.

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

## 7. Hardening — build-time assertions

`home/firefox/default.nix` aborts evaluation (the build) if any invariant
regresses:

* `configPath == ".mozilla/firefox"` — Bug 1 can never silently return.
* `profilePath` is non-empty and **not** absolute — Bug 2 can never return.
* Exactly three declarative add-ons present in `policies.ExtensionSettings`,
  keyed by their real Gecko ids — a renamed/removed extension fails the build
  instead of silently dropping.

Runtime guards (executed on every `home-manager`/NixOS activation):

* `removeStaleFirefoxProfile` — deletes the legacy
  `d0qe8or2.default` left by the broken default.
* `cleanFirefoxExtensions` — removes stale top-level `*.xpi` drop-ins in the
  profile's `extensions/` so the declarative set is the only source
  (extension *state* in `browser-extension-data` is untouched).
* `checkFirefoxProfile` — warns loudly if `profiles.ini` ever gains a
  `*.default` entry or loses the `ivali` profile.

---

## 8. Verification checklist (run after every reinstall)

- [ ] `~/.mozilla/firefox/profiles.ini` → `Name=ivali`, `Path=ivali`,
      `Default=1`, `IsRelative=1`.
- [ ] Firefox shows uBlock Origin, Bitwarden, Dark Reader as
      enabled in `about:addons` → Extensions (installed via policy on first
      launch — **restart Firefox once after a switch/reinstall** for the
      policy to take effect).
- [ ] `~/.mozilla/firefox/ivali/extensions/` contains the staged extension
      directories (the `nixos@*.xpi` sideload drop-ins must be absent).
- [ ] Gruvbox-dark theme + compact density applied (about:preferences →
      "Density: Compact"; native vertical tabs collapsed to the icon rail).
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
3. If a `*.default` entry appears, the build-time assertions likely did not
   fire (e.g. `configPath`/`path` drifted). Fix `home/firefox/default.nix`,
   re-run `nixos-rebuild switch`, then:
   ```bash
   rm -rf ~/.mozilla/firefox/*.default
   ```
   and confirm `profiles.ini` again references only `ivali`.

---

## 10. Native vertical tabs usage

Native vertical tabs (`sidebar.revamp` + `sidebar.verticalTabs`) replace the
horizontal tab bar with a tab strip in the sidebar; no extension is involved.
`sidebar.visibility = "expand-on-hover"` collapses the sidebar to a slim icon
rail that expands on hover.

**Everyday use**
- The sidebar sits collapsed on the left by default, showing the favicons of
  your **pinned tabs** (and the active tab). Hover over the rail to expand the
  full tab list; move the pointer away to collapse it again.
- **Pin a tab:** right-click any tab → "Pin Tab". Pinned tabs stay at the top
  of the rail, always visible as icons even when the sidebar is collapsed.
- Open a link with middle-click / Ctrl+click → new **background** tab (no focus
  theft, per the browsing prefs).
- Pinned / open tab state is Firefox session data and persists in the `ivali`
  profile directory across restarts and rebuilds.
- Window chrome (Gruvbox-dark) is themed via `userChrome.css`.

**Customization (declarative, in `home/firefox/default.nix`)**
- `sidebar.visibility = "expand-on-hover"` — collapsed icon rail; alternatives:
  `"always-show"` (full sidebar always open) or `"hide-sidebar"`.
- `sidebar.animation.expand-on-hover.duration-ms = 50` — snappy expand/collapse.
- Firefox's native vertical tabs are a first-class feature (stable since FF 137);
  they need no per-profile state to be re-declared.

---

## 11. Production readiness summary

**Ready.** The declarative config, profile wiring, extension installation, UI
customization, session-persistence prefs, build-time assertions, and runtime
guards are all in place. Real-world verification is a `nixos-rebuild switch`
on the live host followed by confirming all three extensions are enabled and a
re-login test survives a rebuild — see §8.
