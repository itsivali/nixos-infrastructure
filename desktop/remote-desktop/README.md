# Remote Desktop (RDP over Tailscale)

GNOME Remote Desktop (GRD) provides RDP access to the live GNOME session,
restricted to the Tailscale overlay network.

## How it works

Two complementary modules own this capability:

| Layer | Module | Owns |
|-------|--------|------|
| System (NixOS) | `desktop/remote-desktop/grd.nix` | GRD daemon, Tailscale firewall rule, operator helper script |
| User (Home Manager) | `home/gnome/remote-desktop.nix` | `org.gnome.desktop.remote-desktop.rdp` dconf (backend switch, port, screen-mirror mode, view-only) |

## Enable

```nix
# hosts/<name>.nix
ivali.desktop.remote-desktop.enable = true;
```

This opens TCP 3389 **only on `tailscale0`** (the SSH firewall pattern in
`ssh/daemon.nix`). The port stays closed on public interfaces.

## First-time setup

1. Rebuild and re-login (the RDP backend enables automatically for the
   desktop user).
2. Set credentials once:
   ```bash
   ivali-remote-desktop credentials
   ```
   (wraps `grdctl rdp set-credentials`; stored in the GNOME keyring).
3. Connect from any RDP client on the tailnet to:
   ```
   <tailscale-ip>:3389
   ```

## Operator commands

```bash
ivali remote status        # grdctl status
ivali remote enable        # enable backend for this user
ivali remote disable       # disable backend
ivali remote set-port 3390 # change listen port
ivali remote credentials   # set username/password (keyring)
ivali remote daemon        # systemd user-unit status
```

## Security notes

- TLS uses GRD's auto-generated self-signed certificate
  (`~/.local/share/gnome-remote-desktop/certs/`). Clients present a
  one-time trust prompt; this is expected inside an encrypted tailnet.
- `view-only` is disabled so remote clients can control input.
- `negotiate-port` is off: the firewall only opens the configured port.
- Credentials live in the per-user GNOME keyring — never in the repo.

## Troubleshooting

```bash
journalctl --user -u gnome-remote-desktop.service -b
```

If `grctl status` shows `Closed`/`Inactive`, confirm the user session has
the backend enabled (`ivali remote status`) and the GRD daemon is running
(`ivali remote daemon`).