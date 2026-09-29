# Plan: Enable exFAT Kernel Support

## Problem
USB drives formatted with exFAT are not accessible. Error: "exfat not configured in kernel"

## Root Cause
The NixOS kernel configuration in `boot/kernel.nix` does not include the `exfat` kernel module. The in-kernel exFAT driver has been available since Linux 5.7, and the Zen kernel (used in this repo) is based on recent mainline (6.x/7.x), so it supports this driver.

## Solution
Add `"exfat"` to `boot.kernelModules` in `boot/kernel.nix`.

## Files to Modify
- `/home/ivali/nixos-infrastructure/boot/kernel.nix` - Add exfat to kernelModules list

## Implementation Steps
1. Edit `boot/kernel.nix`
2. Add `"exfat"` to the `boot.kernelModules` array (line 62-70)
3. Run verification gates:
   - `nix fmt -- --check .`
   - `nix flake check --no-build`
   - `nix eval .#nixosConfigurations.prague.config.system.build.toplevel.name`
   - `go build ./... && go test -race -count=1 ./...`

## Validation
- After rebuild, exFAT-formatted USB drives should mount automatically
- Verify with: `lsmod | grep exfat` and `mount | grep exfat`

## Risk Assessment
- Low risk: Adding a standard kernel module that's been in mainline since 2019
- No architectural changes required
- Follows existing pattern in the same file

## Rollback
Revert the single-line change to `boot.kernel.nix`