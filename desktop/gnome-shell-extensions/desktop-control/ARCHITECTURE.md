# Desktop Control Extension — Architecture

## Overview

Desktop Control is a GNOME Shell 50 extension that exposes desktop automation over D-Bus. A Telegram bot calls D-Bus methods to list windows, focus them, switch workspaces, and launch applications.

## Data Flow

```
Telegram user sends command (/windows, /focus, etc.)
    ↓
bot.sh → commands/windows.sh → desktop::ext_dbus_call(method, args)
    ↓
gdbus call --session --dest org.gnome.Shell.Extensions.DesktopControl \
    --method org.gnome.Shell.Extensions.DesktopControl.ListWindows
    ↓
extension.js (lifecycle)
    ↓
dbus.js (validation + dispatch)
    ↓
desktop.js (facade)
    ↓
windows.js / workspaces.js / applications.js
    ↓
global.display.get_windows() / global.workspace_manager / Shell.AppSystem
```

## Module Responsibilities

### extension.js
- Only file GNOME Shell loads directly
- Extends `Extension` class, implements `enable()`/`disable()`
- Instantiates `DesktopControlDbus`, calls `export()`/`unexport()`
- Contains zero business logic

### dbus.js
- Defines D-Bus interface XML (single source of truth)
- Creates `Gio.DBusExportedObject` via `wrapJSObject()`
- Validates all inputs before dispatch
- Delegates to `desktop.js`
- Handles errors and returns structured JSON responses

### desktop.js
- High-level facade that orchestrates domain modules
- Instantiates `windows.js`, `workspaces.js`, `applications.js`
- Catches exceptions from domain modules, wraps in structured responses
- No direct GNOME API calls

### windows.js
- Window enumeration via `global.display.get_windows()` (GNOME 50)
- Window matching via regex or substring (in `utils.js`)
- Operations: list, activate, close, minimize, maximize, move, resize, fullscreen, unfullscreen
- Filters out skip-taskbar and non-normal window types

### workspaces.js
- Workspace queries via `global.workspace_manager`
- Current workspace, total count, list, switch, move window

### applications.js
- Application queries via `Shell.AppSystem.get_default()`
- Running apps list, launch, activate, quit

### logger.js
- Structured logging with `[DesktopControl]` prefix
- Four levels: debug, info, warn, error
- Uses `console.*` methods (GNOME 45+ standard)

### utils.js
- JSON serialization, type validation, structured responses
- Core window-matching algorithm (regex + substring)
- `currentTime()` wrapper for `global.display.get_current_time_roundtrip()`

## Design Decisions

### Why no fallback window enumeration
GNOME Shell 50 has a stable `global.display.get_windows()` API. Fallback code for older versions (get_tab_list, get_window_actors) adds complexity without value. This extension targets GNOME 50 exclusively.

### Why a facade layer (desktop.js)
The facade decouples D-Bus from domain logic. Adding new operations (screenshot, audio, etc.) requires changes only in the domain module + facade + D-Bus interface — not in the core lifecycle.

### Why structured JSON responses
All operations return `{ok: true/false, data?, error?}`. This gives callers a consistent contract. Raw data queries (ListWindows, CurrentWorkspace) return their natural types for efficiency.

### Why regex in window matching
Regex support enables complex queries like `/Firefox|Chrome/` for multi-app operations. The security cost is minimal since the regex runs in GJS (not shell) and only against window metadata.

### Why clean D-Bus break from v1
The old method names (GetRunningApps, GetActiveWorkspace) followed a Java-style getter convention. The new names (RunningApplications, CurrentWorkspace) are more idiomatic for D-Bus and shorter. Since this is a single-user system, backward compatibility is not needed.
