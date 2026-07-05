# Desktop Control Extension — Troubleshooting

## Extension Not Responding

### Check if the extension is installed
```bash
ls /run/current-system/sw/share/gnome-shell/extensions/desktop-control@prague.ivali/
```

### Check if it's enabled
```bash
gnome-extensions show desktop-control@prague.ivali
gnome-extensions list --enabled | grep desktop-control
```

### Check GNOME Shell logs
```bash
journalctl -f -o cat /usr/bin/gnome-shell | grep -i desktop
```

### Restart GNOME Shell
- Wayland: Log out and back in
- X11: `Alt+F2` → `r` → Enter

## D-Bus Call Fails

### Check if the service is on the bus
```bash
gdbus introspect --session \
  --dest org.gnome.Shell.Extensions.DesktopControl \
  --object-path /org/gnome/Shell/Extensions/DesktopControl
```

### Check the session bus address
```bash
echo $DBUS_SESSION_BUS_ADDRESS
# Should be: unix:path=/run/user/1000/bus
```

### Test with gdbus directly
```bash
gdbus call --session \
  --dest org.gnome.Shell.Extensions.DesktopControl \
  --object-path /org/gnome/Shell/Extensions/DesktopControl \
  --method org.gnome.Shell.Extensions.DesktopControl.Ping
# Should return: (true,)
```

## Bot Cannot Reach Extension

### Check session environment bridging
```bash
# As the DEFAULT_USER:
source scripts/bot/lib/desktop.sh
desktop::ensure_session_env
echo $DBUS_SESSION_BUS_ADDRESS
```

### Check the bus socket exists
```bash
ls -la /run/user/$(id -u ivali)/bus
```

### Run the smoke test
```bash
tests/bot-desktop-smoke.sh
```

## Window Operations Fail

### List windows to verify
```bash
gdbus call --session \
  --dest org.gnome.Shell.Extensions.DesktopControl \
  --object-path /org/gnome/Shell/Extensions/DesktopControl \
  --method org.gnome.Shell.Extensions.DesktopControl.ListWindows
```

### Check window title/class
The query must match the window's title or WM_CLASS exactly (case-insensitive substring) or match a regex pattern.

## Build Fails

### Validate the flake
```bash
nix flake check --no-build
```

### Check Nix syntax
```bash
nix-instantiate --parse desktop/desktop-control.nix
```

### Rebuild with verbose output
```bash
sudo nixos-rebuild switch --flake .#prague --option verbose 1
```

## Common Error Messages

| Error | Cause | Fix |
|-------|-------|-----|
| `"query: expected non-empty string"` | Empty or missing argument | Provide a non-empty query string |
| `"index: N out of range [0, 64]"` | Invalid workspace index | Use a valid workspace number |
| `"No graphical session found"` | Bot can't find user session | Check XDG_RUNTIME_DIR |
| `"Extension not found"` | Extension not installed or enabled | Rebuild and/or enable via dconf |

## Getting Help

1. Check the journal: `journalctl -f -o cat /usr/bin/gnome-shell`
2. Run D-Bus introspection
3. Check `gnome-extensions show desktop-control@prague.ivali`
4. Run the smoke tests: `tests/bot-desktop-smoke.sh`
