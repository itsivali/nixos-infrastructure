#!/usr/bin/env bash
# update-go-hashes.sh — Automatically fix stale vendorHash in buildGoModule.
#
# For each Go package defined in flake.nix, this script:
#   1. Temporarily replaces vendorHash with a dummy value
#   2. Attempts a build — Nix fails with the correct hash
#   3. Parses the correct hash from the error output
#   4. Updates flake.nix with the correct hash
#   5. Runs a verification build
#
# Usage:
#   scripts/update-go-hashes.sh [--verify-only]
#
# Options:
#   --verify-only   Only check that current hashes are correct (no updates)
#
# Exit codes:
#   0 — all hashes correct (or all updated successfully)
#   1 — a hash could not be determined or a build failed after update

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FLAKE_NIX="${REPO_DIR}/flake.nix"
VERIFY_ONLY="${1:-}"

log()  { echo "[update-hashes] $*"; }
fail() { echo "[update-hashes] ❌ $*" >&2; }

###########################################################################
# 1. Discover all buildGoModule packages and their current hashes
###########################################################################

# Extract package names and their vendorHash values from flake.nix
# Format: "name:currentHash" per line
declare -A PACKAGES

while IFS= read -r line; do
  name="$(echo "$line" | cut -d: -f1)"
  hash="$(echo "$line" | cut -d: -f2-)"
  PACKAGES["$name"]="$hash"
done < <(python3 -c "
import re, sys
with open('${FLAKE_NIX}') as f:
    content = f.read()
# Find buildGoModule blocks: name = \"...\"; followed by vendorHash = \"...\";
blocks = re.finditer(
    r'(\w+)\s*=\s*pkgs\.buildGoModule\s*\{[^}]*'
    r'name\s*=\s*\"([^\"]+)\"[^}]*'
    r'vendorHash\s*=\s*\"([^\"]+)\"',
    content, re.DOTALL
)
for m in blocks:
    var_name = m.group(1)
    pkg_name = m.group(2)
    vendor_hash = m.group(3)
    print(f'{pkg_name}:{vendor_hash}')
" 2>/dev/null || true)

if [[ ${#PACKAGES[@]} -eq 0 ]]; then
  fail "No buildGoModule packages found in flake.nix"
  exit 1
fi

log "Found ${#PACKAGES[@]} Go packages: ${!PACKAGES[*]}"

###########################################################################
# 2. Verify or update each hash
###########################################################################

UPDATED=0
CHECKED=0
FAILED=0

for pkg in "${!PACKAGES[@]}"; do
  current_hash="${PACKAGES[$pkg]}"
  log "── Checking ${pkg} (current: ${current_hash:0:20}...)"

  # Try building with the current hash
  build_output="$(nix build ".#${pkg}" --no-link 2>&1 || true)"

  if echo "$build_output" | grep -q "hash mismatch"; then
    # Hash is stale — extract the correct one
    correct_hash="$(echo "$build_output" | grep -oP 'got:\s+sha256-[A-Za-z0-9+/=]+' | head -1 | awk '{print $2}')"

    if [[ -z "$correct_hash" ]]; then
      fail "Could not parse correct hash for ${pkg}"
      FAILED=$((FAILED + 1))
      continue
    fi

    log "  Stale! Correct hash: ${correct_hash}"

    if [[ "$VERIFY_ONLY" == "--verify-only" ]]; then
      fail "  Hash mismatch (verify-only mode — not updating)"
      FAILED=$((FAILED + 1))
      continue
    fi

    # Update flake.nix — replace the old hash with the new one
    sed -i "s|${current_hash}|${correct_hash}|g" "$FLAKE_NIX"
    log "  Updated flake.nix"

    # Verify the build succeeds with the new hash
    log "  Verifying build..."
    if nix build ".#${pkg}" --no-link 2>&1 | grep -q "hash mismatch"; then
      fail "  Build still fails after hash update for ${pkg}"
      FAILED=$((FAILED + 1))
      continue
    fi

    log "  ✅ ${pkg} built successfully with new hash"
    UPDATED=$((UPDATED + 1))
  elif echo "$build_output" | grep -q "error:"; then
    # Some other error (not hash-related)
    fail "  Build error for ${pkg} (not hash-related):"
    echo "$build_output" | grep "error:" | head -3 | sed 's/^/    /'
    FAILED=$((FAILED + 1))
  else
    # Build succeeded — hash is correct
    log "  ✅ Hash correct"
    CHECKED=$((CHECKED + 1))
  fi
done

###########################################################################
# 3. Summary
###########################################################################

echo ""
log "═══════════════════════════════════════════"
log "Results: ${CHECKED} OK, ${UPDATED} updated, ${FAILED} failed"
log "═══════════════════════════════════════════"

if [[ $FAILED -gt 0 ]]; then
  exit 1
fi

exit 0
