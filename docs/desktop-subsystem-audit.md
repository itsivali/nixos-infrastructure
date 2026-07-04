# Desktop Subsystem Audit

> Generated: 2026-07-04
> Host: `prague` — GNOME Shell 50.2, Wayland
> Owner: `ivali`

## Diagnostic Results

### 1. Session Type

**Result:** Wayland

```
$ loginctl show-session 2 -p Type
Type=wayland
```

`desktop/gnome-lean.nix` has `MOZ_ENABLE_WAYLAND=1` and `CLUTTER_BACKEND=wayland`.

**Implication:** X11-only tools (`xdotool`, `wmctrl`, `xclip`, `xsel`, `xrandr`-based brightness)
are non-functional. All desktop automation must use Wayland-native or D-Bus paths.

---

### 2. Bot Service Environment

**Result:** System-level `systemd` service running as `root` with NO session environment.

```
$ systemctl show ivali-bot -p User,Group,Type
User=root
Group=root
Type=simple
```

Key env vars present in the service:
- `DEFAULT_USER=ivali`, `HOST_NAME=prague`, `REPO_DIR=/home/ivali/nixos-infrastructure`

Key env vars **missing** from the service:
- `DBUS_SESSION_BUS_ADDRESS` — **absent**
- `WAYLAND_DISPLAY` — **absent**
- `XDG_RUNTIME_DIR` — **absent**

The service has `after = [ "network-online.target" ]` and `wantedBy = [ "multi-user.target" ]`.
It does NOT depend on `graphical-session.target`.

**Bottom line:** Every `gdbus call --session` and every Wayland-native tool invocation
fails because the runtime environment has no D-Bus session bus address or Wayland display.

---

### 3. D-Bus Session Bus Reachability

**From clean root environment (simulating bot runtime):**
```
$ env -i PATH=/run/current-system/sw/bin gdbus call --session ...
Error connecting: Cannot autolaunch D-Bus without X11 $DISPLAY
```

**From `sudo -u ivali` with explicit env:**
```
$ sudo -u ivali XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
  gdbus call --session --dest org.freedesktop.DBus ...
['org.freedesktop.DBus', 'org.gnome.Shell', 'org.gnome.Shell.Screenshot', ...]
```

**Conclusion:** D-Bus session bus is reachable with correct env vars. Root cause is
missing env vars in the service unit, not system policy.

---

### 4. GNOME Shell Eval & Introspect Interfaces

**Eval interface** — present but completely blocked:
```
$ gdbus introspect --session --dest org.gnome.Shell --object-path /org/gnome/Shell
  interface org.gnome.Shell {
    methods: Eval(in  s script, out b success, out s result);
  };

$ gdbus call ... --method org.gnome.Shell.Eval '1+1'
(false, '')
```
Returns `(false, '')` for ALL inputs including `try/catch` wrappers.
Eval is disabled by GNOME Shell 45+ security hardening.

**Introspect.GetWindows** — present but access-denied:
```
$ gdbus call ... --method org.gnome.Shell.Introspect.GetWindows
Error: GDBus.Error:org.freedesktop.DBus.Error.AccessDenied: GetWindows is not allowed
```

**Screenshot.Screenshot** — present but access-denied:
```
$ gdbus call ... --method org.gnome.Shell.Screenshot.Screenshot false false /tmp/shot.png
Error: GDBus.Error:org.freedesktop.DBus.Error.AccessDenied: Screenshot is not allowed
```

**Conclusion:** All three critical Shell D-Bus APIs are present on the bus but blocked
from external callers. A GNOME Shell extension (which runs inside gnome-shell's process
context) CAN access these APIs and expose them via a custom D-Bus interface.

---

### 5. Per-Command Tool Audit

| Command | Current Tool | Wayland? | Status | Fix |
|---------|-------------|----------|--------|-----|
| `/windows` | `org.gnome.Shell.Eval` | N/A | 🔴 Blocked | Extension |
| `/focus` | `org.gnome.Shell.Eval` | N/A | 🔴 Blocked | Extension |
| `/close` | `org.gnome.Shell.Eval` | N/A | 🔴 Blocked | Extension |
| `/workspace` | `org.gnome.Shell.Eval` | N/A | 🔴 Blocked | Extension |
| `/screenshot` | `gnome-screenshot -f` | Wayland | 🔴 Broken under Wayland | Extension |
| `/clipboard` | `wl-copy`/`wl-paste` | ✅ Native | ✅ Works with env | Fix env pass |
| `/volume` | `wpctl` | ✅ Native | ✅ Works with env | Fix env pass |
| `/brightness` | `brightnessctl` | N/A | ✅ Should work as root | Keep as-is |
| `/lock` | `loginctl lock-session` | N/A | ✅ Expected OK | Keep as-is |
| `/logout` | `gnome-session-quit` | ✅ | Needs session env | Add env pass |
| `/suspend` | `systemctl suspend` | N/A | ✅ Expected OK | Keep as-is |
| `/monitoroff` | `org.gnome.ScreenSaver.SetActive` | ✅ Native | ✅ Works with env | Fix env pass |
| `/monitoron` | `org.gnome.ScreenSaver.SetActive` | ✅ Native | ✅ Works with env | Fix env pass |

**Confirmed working with proper session env:**
- `wpctl get-volume @DEFAULT_AUDIO_SINK@` → `Volume: 0.28`
- `wl-copy` / `wl-paste` → clipboard roundtrip successful
- `org.gnome.ScreenSaver.SetActive true` → screen blanks correctly
- D-Bus session bus listing: all expected services available

---

### 6. AppArmor Confinement

**Profile status:** `flags=(complain)` — denials are logged but NOT enforced.

```
$ journalctl -u ivali-bot --since 24h | grep -i apparmor
(no output — no denials logged)
```

**Gaps in current profile:**
- No exec rules for `wl-copy`, `wl-paste`, `wpctl`, `gdbus`, `brightnessctl`
- No socket access rules for `/run/user/*/bus`, `/run/user/*/wayland-*`
- No read access to `/proc/*/environ` (needed for session env bridging)
- Existing `xdotool`, `xclip`, `xsel` executables listed but irrelevant on Wayland

---

### 7. Polkit and Permission Boundaries

- `brightnessctl` as root has direct backlight access — no polkit needed
- `systemctl suspend/hibernate` as root works without polkit
- `loginctl` as root works without polkit
- D-Bus session bus access via `/run/user/1000/bus` is group/world-readable — no polkit
- Wayland socket `/run/user/1000/wayland-0` is world-readable — no polkit

## Root Cause Summary

| Priority | Root Cause | Status | Affects |
|----------|-----------|--------|---------|
| **P0** | System service lacks `DBUS_SESSION_BUS_ADDRESS`, `WAYLAND_DISPLAY`, `XDG_RUNTIME_DIR` | 🔴 Broken | ALL desktop commands |
| **P0** | `org.gnome.Shell.Eval` fully blocked on GNOME 50.2 | 🔴 Broken | windows, workspace, focus, close |
| **P1** | `org.gnome.Shell.Introspect.GetWindows` access-denied externally | 🔴 Broken | window listing |
| **P1** | `org.gnome.Shell.Screenshot.Screenshot` access-denied externally | 🔴 Broken | screenshot |
| **P1** | `gnome-screenshot` CLI broken under Wayland (X11 fallback fails) | 🔴 Broken | screenshot |
| **P2** | `config.sh` `${HOME}` resolves to `/root/` not `/home/ivali/` | 🔴 Bug | app discovery |
| **P3** | `desktop/discovery.sh` has dead duplicate `_parse_desktop_file` | 🟡 Smell | code quality |
| **P3** | AppArmor profile missing exec/socket rules (complain mode masks this) | 🟡 Gap | future enforcement |

## Solution Architecture

```
┌─────────────────────────────────────────────┐
│             bot.sh (root)                     │
│  ┌─────────────────────────────────────┐     │
│  │ lib/desktop.sh (session bridge)     │     │
│  │  → desktop::ensure_session_env()    │     │
│  │  → desktop::ext_dbus_call()         │     │
│  │  → desktop::launch()                │     │
│  └──────────┬──────────────────────────┘     │
│             │                                  │
│  ┌──────────▼──────────────────────────┐     │
│  │ command/*.sh                        │     │
│  │  → calls lib/desktop.sh helpers     │     │
│  └──────────┬──────────────────────────┘     │
└─────────────┼────────────────────────────────┘
              │ sudo -u ivali + session env
              ▼
┌──────────────────────────────┐
│ GNOME Shell (pid 2695)       │
│  ┌────────────────────────┐  │
│  │ DesktopControl Extension│  │  D-Bus service
│  │  → ListWindows()        │  │    org.gnome.Shell.Extensions.DesktopControl
│  │  → FocusWindow()        │  │
│  │  → Screenshot()         │  │
│  │  → SwitchWorkspace()    │  │
│  └────────────────────────┘  │
└──────────────────────────────┘
```

No X11 fallback path. All desktop commands use either:
1. **Extension D-Bus** (windows, workspace, screenshot, focus, close)
2. **Session-bridged native tools** (wl-clipboard, wpctl, ScreenSaver)
3. **Root-privileged hardware access** (brightnessctl, systemctl)
