# Troubleshooting

## Flake Evaluation Errors

### "attribute 'X' missing"

**Cause:** A module references an option or variable that doesn't exist.

**Fix:** Check that the option is declared in `options.nix` and the module
is properly imported.

### "The option 'X' has conflicting definition values"

**Cause:** Multiple modules define the same option with different values.

**Fix:** Use `lib.mkDefault value` for lower priority or `lib.mkForce value`
for higher priority. Or remove the duplicate definition.

### "module does not look like a module"

**Cause:** A NixOS module file doesn't return a proper attrset.

**Fix:** Ensure the file returns either:
- An attrset with `config` and/or `options` keys, or
- A function `{ config, lib, ... }: { ... }` returning config

### "Path 'X' does not exist in Git repository"

**Cause:** Relative path resolves incorrectly.

**Fix:** Paths are relative to the file location. Use `../../` to go up
two levels from `lib/host-templates/` to reach repo root.

## Build Errors

### "nixos-rebuild" fails with timeout

**Cause:** Large rebuild (first run or major changes).

**Fix:** Wait 10-20 minutes. Nix downloads and builds many packages.

### "error: derivation contains forbidden references to the store"

**Cause:** A derivation references `/nix/store` paths.

**Fix:** Use `postPatch` or `substituteInPlace` to fix paths.

## SOPS/Secrets Errors

### "secret not found at /run/secrets/X"

**Cause:** SOPS secret not configured or not decrypted.

**Fix:**
1. Check `secrets/*.yaml` exists and is encrypted
2. Verify `.sops.yaml` configuration
3. Ensure age key is at `/var/lib/sops-nix/key.txt`
4. Rebuild: `sudo nixos-rebuild switch --flake .#<name>`

### "Error getting data key: no key could decrypt the data key"

**Cause:** Age key doesn't match the key used to encrypt secrets.

**Fix:** Re-encrypt secrets with the correct age key:
```bash
sops updatekeys secrets/tailscale.yaml
```

## Tailscale Errors

### "unable to connect to Tailscale"

**Cause:** Tailscale service not running or auth key expired.

**Fix:**
1. Check status: `sudo tailscale status`
2. Restart: `sudo systemctl restart tailscaled`
3. Re-authenticate: `sudo tailscale up`

### "DNS not resolving"

**Cause:** Split DNS not configured or Tailscale DNS disabled.

**Fix:** Ensure `acceptDns = false` in Tailscale config and
NetworkManager handles DNS via systemd-resolved.

## Home Manager Errors

### "username missing"

**Cause:** `username` not passed via `extraSpecialArgs`.

**Fix:** Ensure `flake.nix` passes `username` in `extraSpecialArgs`:
```nix
extraSpecialArgs = {
  username = hostSpec.userName or defaultUsername;
};
```

### "activation failed"

**Cause:** Home Manager config has errors.

**Fix:** Check `~/.nix-profile/` and `~/.local/share/nix/` for backups.
Restore from `~/.config/home-manager/` backup.

## GitLab Runner Errors

### "runner not picking up jobs"

**Cause:** Runner not registered or tags don't match.

**Fix:**
1. Check runner status: `sudo systemctl status gitlab-runner`
2. Verify tags in `hosts/<name>.nix` match GitLab project tags
3. Check registration: `sudo gitlab-runner list`

## Performance Issues

### "system slow after rebuild"

**Cause:** Large store, many generations, or garbage collection needed.

**Fix:**
```bash
sudo nix store gc --max 10G    # Limit store to 10GB
sudo nix-collect-garbage -d   # Remove old generations
```

### "disk full"

**Cause:** Nix store growing unbounded.

**Fix:**
```bash
sudo nix store optimise        # Deduplicate store
sudo nix store gc             # Garbage collect
# Remove old generations
sudo nix-env --delete-generations old --profile /nix/var/nix/profiles/system
```

## Getting Help

### Diagnose Issues

```bash
ivali doctor          # Full health check
ivali doctor --fix    # Auto-fix common issues
ivali status          # Repository state
```

### Check Logs

```bash
journalctl -u deployment-health.service    # Health check logs
journalctl -u gitops-reconciler.service    # Reconciler logs
```

### NixOS Generation Info

```bash
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
```
