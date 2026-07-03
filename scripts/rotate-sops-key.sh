#!/usr/bin/env bash
# rotate-sops-key.sh — SOPS age key rotation procedure
#
# This script generates a new age key and provides instructions
# for re-encrypting all secrets.
#
# Usage:
#   ./scripts/rotate-sops-key.sh
#
# IMPORTANT: This script does NOT automatically re-encrypt secrets.
# It generates a new key and provides manual steps for re-encryption.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== SOPS Key Rotation ==="
echo ""
echo "This will generate a new age key for SOPS encryption."
echo ""
echo "Current key location: /home/ivali/.config/sops/age/keys.txt"
echo ""

# Check if current key exists
if [ -f "/home/ivali/.config/sops/age/keys.txt" ]; then
  echo "Current key found. Creating backup..."
  BACKUP="/home/ivali/.config/sops/age/keys.txt.backup.$(date +%Y%m%d_%H%M%S)"
  cp "/home/ivali/.config/sops/age/keys.txt" "$BACKUP"
  echo "✓ Backup created: $BACKUP"
  echo ""
fi

# Generate new age key
echo "Generating new age key..."
mkdir -p /home/ivali/.config/sops/age
age-keygen -o /home/ivali/.config/sops/age/keys.txt
echo "✓ New age key generated"
echo ""

# Get the public key
PUB_KEY=$(age-keygen -y /home/ivali/.config/sops/age/keys.txt)
echo "✓ Public key: $PUB_KEY"
echo ""

# List all encrypted files
echo "Encrypted secrets files:"
find "$REPO_DIR/secrets" -name "*.yaml" -type f 2>/dev/null | while read -r f; do
  echo "  - ${f#"$REPO_DIR"/}"
done
echo ""

echo "=== Next Steps ==="
echo ""
echo "1. Update .sops.yaml with the new public key:"
echo "   Add the new key to the 'keys' list under 'age'"
echo ""
echo "2. Re-encrypt each secrets file:"
for f in "$REPO_DIR"/secrets/*.yaml; do
  if [ -f "$f" ]; then
    REL="${f#"$REPO_DIR"/}"
    echo "   sops -e -i $REL"
  fi
done
echo ""
echo "3. Test the new key works:"
echo "   sudo nixos-rebuild switch --flake .#prague"
echo ""
echo "4. Remove the old key from .sops.yaml (keep backup for 30 days)"
echo ""
echo "=== Rotation Instructions Complete ==="
echo ""
echo "DO NOT proceed without re-encrypting secrets!"
echo "The system will fail to decrypt secrets with the new key."
