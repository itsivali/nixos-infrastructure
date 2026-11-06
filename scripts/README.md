# Scripts

This directory contains shell scripts for infrastructure automation, GitOps reconciliation, and operational tasks.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `REPO_DIR` | `/home/ivali/nixos-infrastructure` | Path to the NixOS infrastructure repository |
| `HOST_NAME` | `$(hostname)` | Target host for deployment operations |
| `DEFAULT_USER` | `ivali` | Default user for desktop command execution |

## Scripts

### Install & Bootstrap

| Script | Purpose | Systemd Unit |
|--------|---------|--------------|
| `install-fresh-nixos.sh` | Bootstrap a fresh NixOS machine: SSH, repo, age key, host spec, build, switch | Manual execution |
| `generate-ssh-key.sh` | Generate an SSH key pair and print it for GitLab | Manual execution |

`install-fresh-nixos.sh` runs end to end on a freshly installed NixOS system
and leaves the host running this flake:

```bash
# Fresh machine, new age key, key uploaded to GitLab automatically
GITLAB_TOKEN=glpat-... ./scripts/install-fresh-nixos.sh --fresh --yes

# Migrating an existing host (reuse the age key so secrets still decrypt)
./scripts/install-fresh-nixos.sh --migrate --age-key-file /mnt/usb/keys.txt

# Evaluate and build only, never activate (CI / rehearsal)
./scripts/install-fresh-nixos.sh --no-rebuild      # stop before building
./scripts/install-fresh-nixos.sh --build-only      # build, do not switch
```

What it does for SSH:

1. Generates `~/.ssh/id_ed25519` (`-a 100`, no passphrase so GitOps stays
   unattended) and loads it into a temporary `ssh-agent`.
2. Pins the `gitlab.com` and `github.com` host keys in `~/.ssh/known_hosts`
   instead of trusting them on first use. The same keys are declared in
   `ssh/client.nix` — keep both in sync.
3. Writes a marker-delimited managed block in `~/.ssh/config` (forge and
   tailnet `Host` entries). Hand-written entries are preserved; the block is
   rewritten on every run. Opt out with `--no-ssh-config`.
4. Registers the public key with GitLab — via the API when `--gitlab-token` /
   `GITLAB_TOKEN` is set, otherwise with a guided prompt.
5. Probes `ssh -T git@<forge>` and retries until authentication actually
   succeeds, instead of assuming the key was added.
6. Adds the key to `sshAuthorizedKeys` in `hosts/<host>.nix` so inbound SSH
   over the tailnet works after the switch (`--no-authorize-local-key` opts
   out; `--ssh-keys` adds other devices).
7. After the switch, verifies `sshd`, the listening port,
   `/etc/ssh/authorized_keys.d/<user>`, and prints the host key fingerprints.

Running it from inside the checkout it updates:

- The installer **copies itself to a temp path and re-execs** before touching
  the repo. Without that, `clone_or_update_repo`'s `git checkout` rewrites
  `scripts/install-fresh-nixos.sh` — the file bash is still reading — so the
  next invocation silently runs whatever version the target branch carries.
  (Symptom to recognise: a step counter that disagrees with itself between
  runs, e.g. `[06/26]` then `[16/14]`.)
- If the existing checkout is on a **different branch** than `--branch`, it
  asks before switching, and offers to deploy the checkout as it stands
  instead. Uncommitted changes are reported and left alone. Non-interactive
  runs (`--yes`) still follow `--branch`, as instructed, but say so.

Installing the configuration:

- **Parallel downloads.** A fresh install fetches thousands of store paths, and
  wall-clock is dominated by substitution rather than building. The installer
  raises `max-substitution-jobs` to 32 (Nix default 16), `http-connections` to
  50 (default 25), and `download-buffer-size` to 256 MiB (default 1 MiB — it
  fills instantly under concurrency and stalls every job). Tune with
  `--download-jobs N` / `--http-connections N`. The same values are declared
  system-wide in `system/nix.nix`, so they persist after the first switch —
  keep the two in sync.
- **Trusted-user handling.** These are *restricted* settings: the nix daemon
  discards client-supplied values from an untrusted user and warns about each
  one on every invocation. Stock NixOS trusts only root, and `system/nix.nix`
  grants the operator trust only from the first switch — the very step we want
  to speed up. So the installer:
  1. probes the daemon (`nix store info --json`, not `nix config show`, which
     reports the client's own value without ever asking the daemon);
  2. if untrusted, installs a **runtime-only** override — `/etc/nix/nix.conf`
     is a store symlink, so it copies it to `/run/nix-bootstrap-conf` with an
     extended `trusted-users` line and points the daemon at it through a
     `/run/systemd/system/nix-daemon.service.d` drop-in. Nothing survives a
     reboot. `--no-trust-nix-user` opts out;
  3. removes that override immediately after the switch, since leaving it
     would pin the daemon to the pre-switch config and mask every later
     declarative `nix.settings` change until reboot;
  4. falls back to building via `sudo` (root is always trusted) if elevation
     fails, and to an unprivileged build at default parallelism if that fails
     too — the speed-up never becomes a reason the install fails.
- Generated files (`hosts/<host>.nix`, `hosts/<host>/hardware-configuration.nix`,
  `secrets/hosts/<host>.yaml`, `.sops.yaml`) are **staged in git** — Nix
  evaluates the flake from the git tree and cannot see untracked files.
- The closure is built first (`nix build`), so a build failure never touches
  the running system; `nixos-rebuild switch` then only activates it.
- Post-switch it validates SOPS, `sshd`, failed units, Home Manager, the
  `ivali` CLI, and that the running system matches the closure it built.
- Every step is mirrored to `~/.local/state/ivali/install-<timestamp>.log`.

### GitOps & Deployment

| Script | Purpose | Systemd Unit |
|--------|---------|--------------|
| `gitops-reconcile.sh` | Pull latest changes and rebuild NixOS configuration | `ivali-gitops-reconciler.service` |
| `ci-deploy.sh` | CI/CD deployment script for automated builds | `ivali-ci-deploy.service` |
| `rollback.sh` | Roll back to the previous NixOS generation | Manual execution |
| `deployment-health.sh` | Check deployment health and service status | `ivali-deployment-health.service` |

### Security & Secrets

| Script | Purpose | Systemd Unit |
|--------|---------|--------------|
| `sops-setup.sh` | Initialize SOPS with age encryption | Manual execution |
| `sops-breakglass.sh` | Emergency decryption without SOPS key | Manual execution |
| `rotate-sops-key.sh` | Rotate the SOPS encryption key | Manual execution |
| `gitlab-token-rotate.sh` | Rotate the host GitLab token before expiry | `gitlab-token-rotate.service` |

### Monitoring & Alerting

| Script | Purpose | Systemd Unit |
|--------|---------|--------------|
| `gitlab-runner-health.sh` | Check GitLab Runner health status | `ivali-gitlab-runner-health.service` |
| `gitlab-runner-reconcile.sh` | Reconcile GitLab Runner registration | `ivali-gitlab-runner-reconcile.service` |
| `notify.sh` | Send email notifications | Called by other scripts |
| `bitwarden.sh` | Bitwarden CLI wrapper for secret retrieval | Manual execution |

## Systemd Integration

Most scripts are designed to run as systemd services or timers. The corresponding NixOS modules are in the `automation/` directory.

## Testing

To test a script manually:
```bash
# Dry run gitops reconciliation
REPO_DIR=/path/to/repo HOST_NAME=prague ./gitops-reconcile.sh --dry-run

# Check deployment health
./deployment-health.sh

# Test notification (requires email config)
./notify.sh "Test message"
```

## Troubleshooting

- **Script not found**: Ensure the script is executable (`chmod +x script.sh`)
- **Permission denied**: Scripts may need root access for system operations
- **SOPS errors**: Verify `/run/secrets/` is mounted and SOPS key is available
- **Network errors**: Check firewall rules and Tailscale connectivity
