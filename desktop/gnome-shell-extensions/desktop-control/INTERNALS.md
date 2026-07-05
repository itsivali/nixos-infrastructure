# Desktop Control Extension — Internals

## Window Matching Algorithm

The window matching algorithm in `utils.js` `matchWindow()` supports two modes:

### Substring mode (default)
```bash
gdbus call ... --method ... FocusWindow "Firefox"
```
- Converts query and window properties to lowercase
- Tests against: title, wm_class, app_id
- First match wins (order: title → wm_class → app_id)

### Regex mode
```bash
gdbus call ... --method ... FocusWindow "/Firefox|Chrome/"
```
- Query must start and ends with `/`
- Pattern is compiled with `new RegExp(pattern, 'i')`
- Tested against: title, wm_class, app_id
- Invalid regex patterns return false (never throw)

## Window Filtering

Before matching, `windows.js` filters the raw window list:

1. **Skip taskbar windows** — `win.is_skip_taskbar()` removes pagers, docks, etc.
2. **Normal windows only** — `win.get_window_type() === Meta.WindowType.NORMAL` excludes dialogs, splashes, menus, etc.

This ensures `/windows` only shows meaningful application windows.

## Time API

All window/workspace activations use `global.display.get_current_time_roundtrip()`:

```js
// utils.js
export function currentTime() {
    return global.display.get_current_time_roundtrip();
}
```

This replaces the deprecated `global.get_current_time()`. The roundtrip variant forces a synchronous round-trip to the X server (or Wayland equivalent) to get an accurate timestamp, which is required for focus-stealing prevention to work correctly.

## D-Bus Export Pattern

The extension uses `Gio.DBusExportedObject.wrapJSObject()`:

```js
const info = Gio.DBusNodeInfo.new_for_xml(IFACE_XML);
this._impl = Gio.DBusExportedObject.wrapJSObject(
    info.interfaces[0], serviceInstance);
this._impl.export(Gio.DBus.session, OBJECT_PATH);
```

Key properties:
- `wrapJSObject()` creates a bridge between a JS object and D-Bus
- Method calls on the D-Bus interface invoke the matching JS method
- Return values are auto-marshaled to D-Bus types
- String return values (JSON) are passed as-is

## Error Handling Strategy

Every public method is wrapped in try/catch:

```
extension.js enable/disable → try/catch around D-Bus export
dbus.js service methods → validate inputs, catch domain errors
desktop.js facade → catch domain module exceptions
domain modules → return false/null on errors, log them
```

This ensures:
- GNOME Shell never crashes from extension errors
- D-Bus callers always get a response (even on error)
- Errors are logged for debugging

## Memory Management

The extension avoids memory leaks by:

1. **No signal handlers** — we don't connect to any GObject signals
2. **No timeouts/intervals** — no GLib.timeout_add or GLib.idle_add
3. **Clean disable()** — unexport() removes the D-Bus object, nulls references
4. **No closures** — domain modules are stateless functions

## Future Expansion Points

The architecture is designed for easy extension:

| Feature | Domain module | D-Bus methods |
|---------|--------------|---------------|
| Screenshots | screenshot.js | TakeScreenshot() |
| Audio | audio.js | Volume(), Mute(), DefaultOutput() |
| Display | display.js | Brightness(), MonitorLayout() |
| Clipboard | clipboard.js | ClipboardRead(), ClipboardWrite() |
| Input | input.js | MouseMove(), KeyboardType() |
| Power | power.js | Suspend(), Hibernate(), Shutdown() |
| Files | files.js | OpenFile(), RevealFile() |
| URLs | urls.js | OpenURL() |

Each requires:
1. New domain module with exported functions
2. Facade methods in `desktop.js`
3. D-Bus XML + service methods in `dbus.js`
4. No changes to extension.js or existing modules
