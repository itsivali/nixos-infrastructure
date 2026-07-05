# Desktop Control Extension — D-Bus API Reference

## Service Details

| Property | Value |
|----------|-------|
| Bus name | `org.gnome.Shell.Extensions.DesktopControl` |
| Object path | `/org/gnome/Shell/Extensions/DesktopControl` |
| Interface | `org.gnome.Shell.Extensions.DesktopControl` |

## Response Format

All operation methods return a JSON string:

```json
{"ok": true, "data": true}
{"ok": false, "error": "query: expected non-empty string, got undefined"}
```

Query methods return raw data (JSON arrays, integers, booleans).

## Methods

### Health

#### `Ping() → (b alive)`
Check if the extension is responsive.
```bash
gdbus call --session \
  --dest org.gnome.Shell.Extensions.DesktopControl \
  --object-path /org/gnome/Shell/Extensions/DesktopControl \
  --method org.gnome.Shell.Extensions.DesktopControl.Ping
# (true,)
```

#### `Version() → (s version)`
Return the extension version string.
```bash
gdbus call --session \
  --dest org.gnome.Shell.Extensions.DesktopControl \
  --object-path /org/gnome/Shell/Extensions/DesktopControl \
  --method org.gnome.Shell.Extensions.DesktopControl.Version
# ('2.0.0',)
```

### Windows

#### `ListWindows() → (s windows_json)`
List all managed windows. Returns a JSON array.
```bash
gdbus call --session \
  --dest org.gnome.Shell.Extensions.DesktopControl \
  --object-path /org/gnome/Shell/Extensions/DesktopControl \
  --method org.gnome.Shell.Extensions.DesktopControl.ListWindows
```

Response:
```json
[
  {
    "title": "Firefox",
    "wm_class": "firefox",
    "app_id": "org.mozilla.firefox.desktop",
    "pid": 12345,
    "workspace": 0,
    "minimized": false,
    "focused": true,
    "fullscreen": false,
    "x": 100,
    "y": 50,
    "width": 1920,
    "height": 1080
  }
]
```

#### `FocusWindow(s query) → (s result_json)`
Focus a window. Query matches by title, WM_CLASS, or app_id.
```bash
gdbus call --session \
  --dest org.gnome.Shell.Extensions.DesktopControl \
  --object-path /org/gnome/Shell/Extensions/DesktopControl \
  --method org.gnome.Shell.Extensions.DesktopControl.FocusWindow "Firefox"
# ('{"ok":true,"data":true}',)
```

Query modes:
- `"Firefox"` — case-insensitive substring match
- `"/Firefox|Chrome/"` — regex match (delimited by `/`)

#### `CloseWindow(s query) → (s result_json)`
Close a window matching the query.

#### `MinimizeWindow(s query) → (s result_json)`
Minimize a window matching the query.

#### `MaximizeWindow(s query) → (s result_json)`
Maximize a window matching the query.

#### `MoveWindow(s query, i x, i y) → (s result_json)`
Move a window to coordinates (x, y). x range: -16384 to 16384.

#### `ResizeWindow(s query, i width, i height) → (s result_json)`
Resize a window. width range: 1 to 32768. height range: 1 to 32768.

#### `FullscreenWindow(s query) → (s result_json)`
Make a window fullscreen.

#### `UnfullscreenWindow(s query) → (s result_json)`
Remove fullscreen from a window.

### Workspaces

#### `CurrentWorkspace() → (i index)`
Get the active workspace index.
```bash
gdbus call --session \
  --dest org.gnome.Shell.Extensions.DesktopControl \
  --object-path /org/gnome/Shell/Extensions/DesktopControl \
  --method org.gnome.Shell.Extensions.DesktopControl.CurrentWorkspace
# (0,)
```

#### `WorkspaceCount() → (i count)`
Get the total number of workspaces.

#### `SwitchWorkspace(i index) → (s result_json)`
Switch to workspace at index. Returns structured response.
```bash
gdbus call --session \
  --dest org.gnome.Shell.Extensions.DesktopControl \
  --object-path /org/gnome/Shell/Extensions/DesktopControl \
  --method org.gnome.Shell.Extensions.DesktopControl.SwitchWorkspace 2
# ('{"ok":true,"data":true}',)
```

#### `ListWorkspaces() → (s workspaces_json)`
List all workspaces with metadata.
```json
[
  {
    "index": 0,
    "active": true,
    "n_windows": 3,
    "name": ""
  }
]
```

### Applications

#### `RunningApplications() → (s apps_json)`
List all running applications.
```json
[
  {
    "id": "org.mozilla.firefox.desktop",
    "name": "Firefox",
    "wm_class": "firefox",
    "pids": [12345]
  }
]
```

#### `LaunchApplication(s application_id) → (s result_json)`
Launch an application by its desktop ID.

## Error Handling

All errors are returned as structured JSON, never as D-Bus errors:

```json
{"ok": false, "error": "query: expected non-empty string, got undefined"}
{"ok": false, "error": "index: 100 out of range [0, 64]"}
```

GNOME Shell never crashes from extension errors. Each method is wrapped in try/catch.

## Input Validation

| Method | Argument | Validation |
|--------|----------|------------|
| FocusWindow, CloseWindow, etc. | query | Non-empty string |
| SwitchWorkspace | index | Integer, 0–64 |
| MoveWindow | x, y | Integer, -16384–16384 |
| ResizeWindow | width, height | Integer, 1–32768 |
| LaunchApplication | application_id | Non-empty string |
