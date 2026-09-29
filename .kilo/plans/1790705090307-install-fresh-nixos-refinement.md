# Plan: Refine install-fresh-nixos.sh for Fresh NixOS Install

## Current Issues Identified

### 1. SSH Key Chicken-Egg (Critical)
- **Problem**: Script clones repo via SSH (`git@gitlab.com:...`) but generates SSH key *after* clone
- **Fix**: Generate SSH key first, prompt user to add to GitLab, then clone

### 2. Age Key Requirement (Critical)
- **Problem**: Script requires existing age key from another system (`--age-key-file` or `AGE_KEY` env)
- **Fix**: Support two modes:
  - `--migrate` (default): Copy age key from existing system
  - `--fresh`: Generate new age key, create placeholder secrets, warn about re-encryption

### 3. Flake Enablement Timing
- **Problem**: Fresh NixOS has flakes disabled system-wide; script enables in user config only
- **Fix**: Ensure `nix-command flakes` enabled early; use `--extra-experimental-features` consistently

### 4. Secrets Decryption on First Boot
- **Problem**: If age key not set up properly, `nixos-rebuild switch` fails on sops-nix secrets
- **Fix**: Validate age key + .sops.yaml registration before rebuild; allow partial config without secrets

### 5. Step Ordering Issues
- **Problem**: SSH key generation happens *after* system switch; repo ops need it earlier
- **Fix**: Generate SSH key → add to GitLab → clone repo → continue

### 6. Missing Validation Gates
- **Problem**: No pre-flight checks for disk space, internet, GitLab access
- **Fix**: Add pre-flight validation

---

## Proposed Changes

### Phase 1: Reorder & Fix Chicken-Egg

```bash
# NEW ORDER:
1. Pre-flight checks (disk, network, NixOS version)
2. Enable nix-command + flakes (user config + export)
3. Generate SSH key FIRST (before any GitLab interaction)
4. Prompt user to add SSH key to GitLab
5. Clone repo (now works with fresh SSH key)
6. Detect hardware
7. Age key setup:
   - --migrate: copy from --age-key-file / AGE_KEY env / interactive paste
   - --fresh: generate new age key, create .sops.yaml entries, warn re-encrypt needed
8. Register host spec
9. Validate flake + syntax
10. nixos-rebuild switch
11. Post-switch: validate SOPS, final SSH key setup
```

### Phase 2: Age Key Modes

| Flag | Behavior |
|------|----------|
| `--migrate` (default) | Require existing age key via `--age-key-file`, `AGE_KEY`, or interactive paste |
| `--fresh` | Generate new age key; create per-host secrets placeholder; register in .sops.yaml; warn user to re-encrypt from old machine |
| `--age-key-file PATH` | Explicit source for migrate mode |

### Phase 3: Fresh-Start Secrets Handling

For `--fresh` mode:
1. Generate new age key at `~/.config/sops/age/keys.txt`
2. Register public key in `.sops.yaml` (new anchor for this host)
3. Create `secrets/hosts/${HOST}.yaml` placeholder (unencrypted template)
4. **Warn**: "Secrets are NOT encrypted for this key yet. Run `sops -e -i secrets/*.yaml` from a machine with the old key after adding this key to .sops.yaml"
5. Allow rebuild to proceed (sops-nix will fail on missing secrets, but we can make secrets optional for bootstrap)

### Phase 4: SOPS Optional for Bootstrap

Modify laptop template to make `hasSecrets` conditional:
- If age key exists AND .sops.yaml has key → enable secrets
- If `--fresh` mode → disable secrets for initial boot, enable after re-encryption

Alternative: Keep secrets enabled but provide fallback empty values for critical secrets (tailscale authkey, etc.)

### Phase 5: Robustness Improvements

- Add `--no-secrets` flag to skip SOPS entirely for initial bootstrap
- Add `--no-rebuild` flag to stop before nixos-rebuild (for CI/testing)
- Better error messages with actionable fixes
- Idempotency: safe to re-run after partial failure
- Log file output for debugging

---

## Validation Plan

### Test Scenarios

1. **Migrate mode** (existing system):
   - Run with `--migrate --age-key-file /path/to/keys.txt`
   - Verify age key copied, .sops.yaml updated, rebuild succeeds

2. **Fresh mode** (new system):
   - Run with `--fresh`
   - Verify new age key generated, .sops.yaml registered, placeholder secrets created
   - Verify rebuild succeeds (with secrets disabled or placeholder values)

3. **SSH key flow**:
   - Run on fresh system with no SSH keys
   - Verify key generated, prompt to add to GitLab, clone succeeds after

4. **Idempotency**:
   - Re-run script after partial failure
   - Verify no duplicate keys, no overwrites without confirmation

### Verification Gates (must pass before merge)

```bash
# Local
nix fmt -- --check .
shellcheck --severity=warning scripts/install-fresh-nixos.sh
bash -n scripts/install-fresh-nixos.sh

# CI (GitLab)
# All existing pipeline jobs must pass
```

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| SSH key not added to GitLab in time | High | Clone fails | Clear prompt with URL, wait for user confirmation |
| Age key mismatch breaks secrets | High | Rebuild fails | --fresh mode disables secrets; clear warnings |
| Flake eval fails on fresh config | Medium | Rebuild fails | Validate flake before rebuild; show clear errors |
| Hardware config wrong for new machine | Low | Boot issues | nixos-generate-config fallback; manual review step |
| User runs as root | Low | Permission issues | Early check + die |

---

## Out of Scope

- Adding new hosts to existing fleet (use `ivali bootstrap host`)
- SOPS re-encryption automation (manual step required)
- Multi-host bootstrap in one run
- Non-GNOME desktops (KDE, etc.) - would need template changes

---

## Implementation Checklist

- [ ] Reorder steps: SSH key gen → GitLab prompt → clone
- [ ] Add `--migrate` / `--fresh` flag with age key logic
- [ ] Add `--no-secrets` flag for bootstrap without SOPS
- [ ] Add pre-flight checks (disk, net, NixOS)
- [ ] Make SOPS optional in laptop template for bootstrap
- [ ] Add idempotency guards (skip completed steps)
- [ ] Improve error messages with actionable hints
- [ ] Add `--no-rebuild` flag for testing
- [ ] Update help text and documentation
- [ ] Run shellcheck, nix fmt, bash -n
- [ ] Test both modes manually