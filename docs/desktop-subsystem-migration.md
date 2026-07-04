# Desktop Subsystem Migration Notes

> Deploy date: 2026-07-04
> Affected host: `prague`

## What Changed

### Architecture

The Telegram bot's desktop interaction subsystem was rewritten from an
X11-era/Eval-based design to a Wayland-native, GNOME Shell extension-backed
architecture.

### Root Causes Fixed

1. **Service environment** — `desktop::ensure_session_env()` now discovers
   `DBUS_SESSION_BUS_ADDRESS`, `XDG_RUNTIME_DIR`, and `WAYLAND_DISPLAY` from
   the running gnome-shell process at call-time. No stale env vars in the
   systemd unit. Desktop commands work across session restarts without
   service restart.

2. **org.gnome.Shell.Eval removed** — All window/workspace/screenshot commands
   now call the **DesktopControl GNOME Shell extension** via D-Bus at
   `org.gnome.Shell.Extensions.DesktopControl`. The extension runs inside
   gnome-shell's process and has full access to all Shell/Mutter APIs.

3. **gnome-screenshot replaced** — Screenshots are captured via the extension's
   `Screenshot` method, which internally calls `org.gnome.Shell.Screenshot`
   from the privileged extension context.

4. **wl-clipboard + session env** — Clipboard commands already used
   `wl-clipboard` (Wayland-native) but the session environment was inconsistently
   passed. Now all commands go through `desktop::require_graphical` first.

5. **config.sh HOME bug** — `${HOME}` in `DESKTOP_DIRS` was resolving to
   `/root/` because the service runs as root. Changed to explicit
   `/home/${DEFAULT_USER}`.

6. **AppArmor profile** — Added exec rules for `wl-copy`, `wl-paste`,
   `wpctl`, `gdbus`, `gnome-session-quit` and socket access for
   `/run/user/*/bus`, `/run/user/*/wayland-*`. Also added
   `/proc/*/environ` read (for session env discovery).

### New Files

| File | Purpose |
|------|---------|
| `desktop/gnome-shell-extensions/desktop-control/metadata.json` | Extension metadata |
| `desktop/gnome-shell-extensions/desktop-control/extension.js` | Extension implementation |
| `desktop/desktop-control.nix` | Nix packaging and enablement |
| `docs/desktop-subsystem-audit.md` | Diagnostic report |
| `docs/desktop-subsystem-migration.md` | This file |

### Modified Files

| File | Change |
|------|--------|
| `scripts/bot/lib/desktop.sh` | Full rewrite — session bridging + D-Bus abstraction |
| `scripts/bot/commands/windows.sh` | Use DesktopControl extension |
| `scripts/bot/commands/workspace.sh` | Use DesktopControl extension |
| `scripts/bot/commands/screenshot.sh` | Use DesktopControl extension |
| `scripts/bot/commands/clipboard.sh` | Use `desktop::ensure_session_env` |
| `scripts/bot/commands/volume.sh` | Use `desktop::ensure_session_env` |
| `scripts/bot/commands/desktop_power.sh` | Use `desktop::dbus_call` for monitor commands |
| `scripts/bot/config.sh` | Fixed `${HOME}` → `/home/${DEFAULT_USER}` |
| `scripts/bot/lib/app_registry.sh` | Canonical `_parse_desktop_file` (consolidated from discovery.sh) |
| `scripts/bot/desktop/discovery.sh` | Thin compatibility layer (dead code removed) |
| `services/bot/ivali-bot.nix` | Added `graphical.target` dependency, `partOf` |
| `security/apparmor/profiles/ivali-bot` | Added session bus/Wayland/bin rules |

## One-Time Setup Steps

After deploying the new configuration:

### 1. Enable the GNOME Shell extension

The extension is packaged by `desktop/desktop-control.nix` and enabled via dconf.
After `nixos-rebuild switch`, ivali should:

```
# Log out and back in (or restart GNOME Shell)
Alt+F2 → r → Enter

# Verify it's listed:
gdbus call --session \
  --dest org.gnome.Shell \
  --object-path /org/gnome/Shell \
  --method org.gnome.Shell.Extensions.ListExtensions

# Expected output includes: 'desktop-control@prague.ivali'
```

Alternatively, look in GNOME Extensions app.

### 2. Verify the D-Bus service is registered

```
gdbus introspect --session \
  --dest org.gnome.Shell.Extensions.DesktopControl \
  --object-path /org/gnome/Shell/Extensions/DesktopControl

# Should list: ListWindows, FocusWindow, CloseWindow,
# GetActiveWorkspace, GetWorkspaceCount, SwitchWorkspace,
# Screenshot, GetRunningApps
```

### 3. Restart the bot service

```
systemctl restart ivali-bot
journalctl -fu ivali-bot
```

### 4. Run validation test commands via Telegram

See the "Validation Checklist" section below.

## No New Secrets or Polkit Rules Required

- The D-Bus session bus socket is world-readable at `/run/user/1000/bus`
- The Wayland socket is world-readable at `/run/user/1000/wayland-0`
- No additional polkit rules needed (bot runs as root for brightness/systemctl,
  and uses `sudo -u ivali` with explicit env vars for session-attached calls)
- The extension is self-contained and requires no external API keys

## Rollback

If needed, roll back the service unit and disable the extension:

```
# Disable the extension
sudo -u ivali \
  XDG_RUNTIME_DIR=/run/user/1000 \
  DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
  gsettings set org.gnome.shell enabled-extensions "[]"

# Roll back the NixOS generation
nixos-rebuild switch --rollback
```

## Validation Checklist

Run these Telegram commands against the live bot after deployment.
Each should succeed with the expected response.

| Command | Expected Response | D-Bus Call on Success |
|---------|------------------|----------------------|
| `/windows` | 🪟 Open Windows list (or "No open windows") | `ListWindows` → JSON array |
| `/focus Firefox` | 🪟 Focused: Firefox | `FocusWindow("Firefox")` → true |
| `/close <title>` | 🪟 Closed: <title> (or "not found") | `CloseWindow(title)` → bool |
| `/workspace` | Usage instructions | — |
| `/workspace next` | 🖥 Workspace → N | `GetActiveWorkspace` + `SwitchWorkspace` |
| `/workspace 0` | 🖥 Workspace → 0 | `SwitchWorkspace(0)` |
| `/screenshot` | 📸 Screenshot from *prague* (photo) | `Screenshot(file)` → true |
| `/clipboard` | 📋 Clipboard: ... or "Clipboard is empty" | wl-paste |
| `/clipboard set hello` | 📋 Clipboard set to: hello | wl-copy |
| `/volume` | 🔊 Volume: 0.xx | wpctl get-volume |
| `/volume 75` | 🔊 Volume set to 75% | wpctl set-volume |
| `/brightness` | 🔆 Brightness: N% | brightnessctl info |
| `/brightness 50` | 🔆 Brightness set to 50% | brightnessctl set |
| `/lock` | 🔒 Screen locked | loginctl lock-session |
| `/monitoroff` | 🖥 Display off | ScreenSaver.SetActive(true) |
| `/monitoron` | 🖥 Display on | ScreenSaver.SetActive(false) |
| `/apps` | 📱 Discovered Applications list | Desktop file parsing |

### Expected log lines on success

```
[2026-07-04T...] Command: /screenshot
[2026-07-04T...] Command: /workspace next
```

### Expected log lines on failure (no graphical session)

```
desktop.sh: No graphical session found for ivali on prague.
```

### Failure D-Bus diagnostics

If the extension isn't registered:
```
$ gdbus call --session \
  --dest org.gnome.Shell.Extensions.DesktopControl \
  --object-path /org/gnome/Shell/Extensions/DesktopControl \
  --method org.freedesktop.DBus.Introspectable.Introspect
Error: GDBus.Error:org.freedesktop.DBus.Error.ServiceUnknown: The name org.gnome.Shell.Extensions.DesktopControl was not provided by any .service files
```

Solution: Reinstall the extension, restart GNOME Shell, verify with
`gdbus introspect`.
