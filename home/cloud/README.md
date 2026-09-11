# OneDrive Sync

Declarative Microsoft OneDrive file synchronization using the open-source
[onedrive](https://github.com/abraunegg/onedrive) client, running as a
systemd user service.

## What it does

- Syncs `~/OneDrive` bidirectionally with your Microsoft OneDrive
- Runs automatically at login (systemd user service `onedrive.service`)
- Restarts on failure — crash-loop protection built in

## First-time setup (one-time auth)

The systemd service cannot authenticate for you. You must authenticate
once interactively so the token lands in your GNOME keyring:

```bash
# Start the service so an empty config exists
systemctl --user start onedrive

# Run the monitor in a terminal — a browser opens for Microsoft SSO
onedrive --monitor
```

After you approve in the browser, Ctrl+C out of the monitor and
restart the service:

```bash
systemctl --user restart onedrive
```

Verify it stays running (no crash-loop):

```bash
systemctl --user status onedrive
```

## Day-to-day commands

```bash
# Show sync status
onedrive --display-sync-status

# Force a one-shot sync of everything
onedrive --synchronize

# Force a one-shot sync of a single directory
onedrive --synchronize --single-directory <folder>

# Watch the service
journalctl --user -fu onedrive
```

## Shell aliases

```bash
cloud      # ivali cloud (CLI overview)
od         # ivali cloud onedrive status
odsetup    # ivali cloud onedrive setup
od-start   # onedrive --monitor (interactive first-run auth)
```

## Configuration

Lives in `~/.config/onedrive/config`, generated declaratively by
`home/cloud/onedrive.nix`:

| Key | Value | Purpose |
|-----|-------|---------|
| `sync_dir` | absolute path to `~/OneDrive` | Must be absolute — the client doesn't expand `~` |
| `monitor` | `true` | Watch for changes and sync automatically |
| `disable_notifications` | `true` | Silent background sync |

## Troubleshooting

**Service crash-loops (`Exit code: 1`):**
Check `journalctl --user -u onedrive -b` for `Malformed config line`.
The `sync_dir` must be an absolute path — `~/OneDrive` is not expanded
by onedrive ≥ 2.5. The declarative config already uses the absolute
path; this only matters if you hand-edit the config.

**No browser opens during auth:**
Make sure you run `onedrive --monitor` from a terminal inside your
graphical session (not over SSH or in a systemd context), so the browser
can reach the SSO flow.

**Files sync but notifications appear:**
`disable_notifications = true` suppresses the inotify banner popups.

## Local module structure

```
home/cloud/
├── default.nix     # imports onedrive.nix
└── onedrive.nix    # package, config, systemd user service
```