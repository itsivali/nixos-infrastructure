# Plan: Replace Syncthing iPhone Device ID

## Objective
Replace the Syncthing device ID for the "phone" device in the NixOS configuration with the new device ID: `BMSAYQK-EH6NRFR-GNJ2RPO-NNTTNWU-NDF56CZ-7D7FCL5-LDVRPMM-F35OIQW`

## Background
The Syncthing configuration is defined in `hosts/prague.nix` at lines 88-92. The current device ID for the phone is:
```
ETCBCIH-HQXJV6Z-MZQUVQ6-NT54JVJ-T6276GV-ISNGDKG-HE63NI6-6S3DNQO
```

## Change Required
**File:** `hosts/prague.nix`
**Line:** 89
**Change:** Replace the device ID string for the "phone" device

## Classification
- **Type:** configuration (NixOS module option change)
- **Affected Domain:** runtime/services/internal (syncthing service)
- **Affected Component:** hosts/prague.nix - services.syncthing.settings.devices.phone.id
- **Risk Level:** low (single configuration value change)

## Implementation Steps

### 1. Create Issue and Branch
- Create GitLab issue: `[configuration] Replace Syncthing iPhone device ID`
- Create branch: `bugfix/syncthing-iphone-device-id` (or `configuration/syncthing-iphone-device-id`)

### 2. Implement Change
- Edit `hosts/prague.nix` line 89
- Replace old device ID with new one: `BMSAYQK-EH6NRFR-GNJ2RPO-NNTTNWU-NDF56CZ-7D7FCL5-LDVRPMM-F35OIQW`

### 3. Local Verification
Run verification gates:
```bash
nix fmt -- --check .
nix flake check --no-build
nix eval .#nixosConfigurations.prague.config.system.build.toplevel.name
```

### 4. IVALI Flow
- `ivali flow commit`
- `ivali flow push`
- `ivali flow mr`
- `ivali flow pipeline --watch`
- `ivali flow merge`

## Validation
- Nix evaluation must succeed
- Flake check must pass
- Configuration must evaluate correctly for prague host
- No syntax errors in Nix expression

## Rollback
If needed, revert the single line change in `hosts/prague.nix`

## Documentation
No documentation updates required - this is a device ID rotation.

## Open Questions
None - straightforward device ID replacement.