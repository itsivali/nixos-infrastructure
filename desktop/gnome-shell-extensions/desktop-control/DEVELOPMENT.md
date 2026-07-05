# Desktop Control Extension — Development Guide

## Prerequisites

- NixOS with GNOME Shell 50
- `gjs` for syntax checking
- `jq` for D-Bus response parsing
- GNOME Shell session (for runtime testing)

## Directory Structure

```
desktop/gnome-shell-extensions/desktop-control/
├── extension.js          ← Lifecycle (enable/disable)
├── dbus.js               ← D-Bus interface definition + export
├── desktop.js            ← High-level facade
├── windows.js            ← Window management
├── workspaces.js         ← Workspace management
├── applications.js       ← App system queries
├── logger.js             ← Structured logging
├── utils.js              ← Validation + helpers
└── metadata.json         ← Extension metadata
```

## Development Workflow

### 1. Edit a module
All business logic changes happen in domain modules (`windows.js`, `workspaces.js`, `applications.js`) or the facade (`desktop.js`). D-Bus changes happen in `dbus.js`.

### 2. Syntax check
```bash
gjs -c desktop/gnome-shell-extensions/desktop-control/extension.js
gjs -c desktop/gnome-shell-extensions/desktop-control/dbus.js
# ... repeat for each file
```

### 3. Build the NixOS system
```bash
sudo nixos-rebuild switch --flake .#prague
```

### 4. Restart GNOME Shell
- On X11: `Alt+F2` → `r` → Enter
- On Wayland: log out and back in, or use `busctl --user call org.gnome.Shell /org/gnome/Shell org.gnome.Shell Eval s 'Meta.restart("Restarting…")'`

### 5. Test via D-Bus
```bash
gdbus call --session \
  --dest org.gnome.Shell.Extensions.DesktopControl \
  --object-path /org/gnome/Shell/Extensions/DesktopControl \
  --method org.gnome.Shell.Extensions.DesktopControl.Ping
```

## Adding a New Method

1. Add XML to `IFACE_XML` in `dbus.js`
2. Add validation + dispatch in `DesktopControlService` class in `dbus.js`
3. Add implementation in `desktop.js` (facade)
4. Add logic in the appropriate domain module
5. Add D-Bus documentation in `DBUS.md`
6. Test with `gdbus call`

## Adding a New Domain Module

1. Create `newmodule.js` with exported functions
2. Import it in `desktop.js`
3. Add facade methods that delegate to it
4. Add D-Bus methods in `dbus.js`
5. No Nix changes needed — `cp *.js` in `desktop-control.nix` picks it up automatically

## Debugging

### Journal logs
```bash
journalctl -f -o cat /usr/bin/gnome-shell | grep DesktopControl
```

### D-Bus introspection
```bash
gdbus introspect --session \
  --dest org.gnome.Shell.Extensions.DesktopControl \
  --object-path /org/gnome/Shell/Extensions/DesktopControl
```

### Extension state
```bash
gnome-extensions show desktop-control@prague.ivali
gnome-extensions enable desktop-control@prague.ivali
gnome-extensions disable desktop-control@prague.ivali
```
