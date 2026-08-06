#!/usr/bin/env bash
# sops-setup.sh — install the SOPS age key for a fresh host.
#
# Installs the age private key at $HOME/.config/sops/age/keys.txt. The key is
# the SAME key used on your existing system — never generate a new one here,
# otherwise existing secrets cannot be decrypted (see .sops.yaml).
#
# The age private key is NEVER stored in this repository. Provide it via one of:
#   1. --age-key-file <path>   copy an existing keys.txt
#   2. AGE_KEY env var         the full AGE-SECRET-KEY-... line
#   3. Interactive paste       paste the key line, then Ctrl+D
#
# Usage:
#   ./scripts/sops-setup.sh [--age-key-file /path/to/keys.txt]
#   AGE_KEY='AGE-SECRET-KEY-...' ./scripts/sops-setup.sh
#
# After installing the key, register its public key in .sops.yaml and verify
# with:  sops --decrypt secrets/tailscale.yaml | head

set -euo pipefail

KEY_DIR="${HOME}/.config/sops/age"
KEY_FILE="${KEY_DIR}/keys.txt"
AGE_KEY_FILE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --age-key-file) AGE_KEY_FILE="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: sops-setup.sh [--age-key-file /path/to/keys.txt]"
      echo "Provide the age key via --age-key-file, AGE_KEY env var, or paste."
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

mkdir -p "$KEY_DIR"

if [[ -n "$AGE_KEY_FILE" ]]; then
  [[ -f "$AGE_KEY_FILE" ]] || { echo "ERROR: age key file not found: $AGE_KEY_FILE" >&2; exit 1; }
  cp "$AGE_KEY_FILE" "$KEY_FILE"
elif [[ -n "${AGE_KEY:-}" ]]; then
  printf '%s\n' "$AGE_KEY" > "$KEY_FILE"
elif [[ -f "$KEY_FILE" ]]; then
  echo "Age key already exists at $KEY_FILE — leaving it untouched."
else
  echo "Paste the entire AGE-SECRET-KEY-... line from your existing system,"
  echo "then press Ctrl+D:"
  cat > "$KEY_FILE" || { rm -f "$KEY_FILE"; exit 1; }
fi

chmod 700 "$KEY_DIR"
chmod 600 "$KEY_FILE"

if ! grep -q 'AGE-SECRET-KEY-' "$KEY_FILE"; then
  echo "ERROR: $KEY_FILE does not look like a valid age key." >&2
  exit 1
fi

echo "✅ SOPS age key installed."
echo "   Location: $KEY_FILE"
echo "   Public key: $("${AGE_BIN:-age-keygen}" -y "$KEY_FILE" 2>/dev/null || echo "run: age-keygen -y $KEY_FILE")"
echo
echo "Next: ensure the public key above is present in .sops.yaml, then run:"
echo "   sops --decrypt secrets/tailscale.yaml | head"
