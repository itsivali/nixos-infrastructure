#!/usr/bin/env bash
# validate-hardware.sh — Verify declared filesystem UUIDs match live block devices.
#
# Called before nixos-rebuild switch to prevent writing a bootloader entry
# that references a UUID no longer present on disk (e.g. after disk swap,
# reformat, or partition table change).
#
# Exit codes:
#   0 — all declared UUIDs present (or non-critical warnings only)
#   1 — a declared UUID is MISSING from live block devices (blocks rebuild)
#
# Usage:
#   scripts/validate-hardware.sh [--quiet]
#
# Environment:
#   HOST       — NixOS host name (default: prague)
#   REPO_DIR   — path to the nixos-infrastructure repo (default: auto-detect)

set -euo pipefail

HOST="${HOST:-prague}"
REPO_DIR="${REPO_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
QUIET="${1:-}"

log()  { [[ "$QUIET" == "--quiet" ]] || echo "[hw-check] $*"; }
fail() { echo "[hw-check] ❌ $*" >&2; }

###########################################################################
# 1. Collect live block device UUIDs
###########################################################################

declare -A LIVE_UUIDS

# Method 1: blkid (may need root for full results)
while IFS= read -r line; do
  uuid="$(echo "$line" | grep -oP 'UUID="[^"]*"' | cut -d'"' -f2)"
  [[ -n "$uuid" ]] && LIVE_UUIDS["$uuid"]=1
done < <(blkid 2>/dev/null || true)

# Method 2: /dev/disk/by-uuid/ symlinks (works without root)
for link in /dev/disk/by-uuid/*; do
  [[ -L "$link" ]] || continue
  uuid="$(basename "$link")"
  [[ -n "$uuid" ]] && LIVE_UUIDS["$uuid"]=1
done 2>/dev/null || true

# Bash <4.4 treats empty associative arrays as unset under set -u.
set +u
LIVE_COUNT=${#LIVE_UUIDS[@]}
set -u

if [[ "$LIVE_COUNT" -eq 0 ]]; then
  log "⚠️  blkid returned no UUIDs — skipping validation (container/VM?)"
  exit 0
fi

log "Found ${LIVE_COUNT} live block device UUIDs"

###########################################################################
# 2. Extract declared filesystem UUIDs from the NixOS configuration
###########################################################################

declare -A DECLARED_UUIDS

# Get fileSystems entries
FS_JSON="$(nix eval --json \
  ".#nixosConfigurations.${HOST}.config.fileSystems" 2>/dev/null || echo "{}")"

# Extract UUID fields from the JSON
while IFS= read -r uuid; do
  [[ -n "$uuid" && "$uuid" != "null" ]] && DECLARED_UUIDS["$uuid"]=1
done < <(echo "$FS_JSON" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for mount, fs in data.items():
        dev = fs.get('device', '')
        # device can be a string like '/dev/disk/by-uuid/...' or a list
        if isinstance(dev, str):
            parts = dev.split('/')
            if 'by-uuid' in parts:
                idx = parts.index('by-uuid')
                if idx + 1 < len(parts):
                    print(parts[idx + 1])
        elif isinstance(dev, list):
            for d in dev:
                if isinstance(d, str):
                    parts = d.split('/')
                    if 'by-uuid' in parts:
                        idx = parts.index('by-uuid')
                        if idx + 1 < len(parts):
                            print(parts[idx + 1])
except:
    pass
" 2>/dev/null || true)

# Get swap devices
SWAP_JSON="$(nix eval --json \
  ".#nixosConfigurations.${HOST}.config.swapDevices" 2>/dev/null || echo "[]")"

while IFS= read -r uuid; do
  [[ -n "$uuid" && "$uuid" != "null" ]] && DECLARED_UUIDS["$uuid"]=1
done < <(echo "$SWAP_JSON" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for swap in data:
        dev = swap.get('device', '')
        if isinstance(dev, str):
            parts = dev.split('/')
            if 'by-uuid' in parts:
                idx = parts.index('by-uuid')
                if idx + 1 < len(parts):
                    print(parts[idx + 1])
except:
    pass
" 2>/dev/null || true)

set +u
if [[ ${#DECLARED_UUIDS[@]} -eq 0 ]]; then
  set -u
  log "⚠️  No declared UUIDs found in NixOS config — skipping"
  exit 0
fi
set -u

log "Found ${#DECLARED_UUIDS[@]} declared UUIDs in NixOS config"

###########################################################################
# 3. Compare — declared UUIDs must exist on live block devices
###########################################################################

MISSING=0
for uuid in "${!DECLARED_UUIDS[@]}"; do
  if [[ -z "${LIVE_UUIDS[$uuid]:-}" ]]; then
    fail "DECLARED UUID MISSING from disk: $uuid"
    MISSING=$((MISSING + 1))
  fi
done

if [[ $MISSING -gt 0 ]]; then
  fail "$MISSING declared UUID(s) not found on any block device!"
  fail "Disk layout may have changed. Run 'nixos-generate-config --show-hardware-config'"
  fail "and update hosts/${HOST}/hardware-configuration.nix before rebuilding."
  exit 1
fi

###########################################################################
# 4. Check for undeclared UUIDs (informational only)
###########################################################################

UNDECLARED=0
for uuid in "${!LIVE_UUIDS[@]}"; do
  if [[ -z "${DECLARED_UUIDS[$uuid]:-}" ]]; then
    log "ℹ️  Undeclared UUID on disk (not in config): $uuid"
    UNDECLARED=$((UNDECLARED + 1))
  fi
done

if [[ $UNDECLARED -gt 0 ]]; then
  log "⚠️  $UNDECLARED UUID(s) on disk not declared in NixOS config"
fi

###########################################################################
# 5. Summary
###########################################################################

log "✅ All ${#DECLARED_UUIDS[@]} declared UUIDs match live block devices"
exit 0
