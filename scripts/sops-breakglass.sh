#!/bin/sh
# sops-breakglass.sh — register a break-glass age recipient
#
# Why: a single SOPS age key is a single point of failure for every
# secret. This generates a SECOND, offline-kept recovery key, adds it
# as a SOPS recipient, and re-encrypts all secrets so EITHER key
# can decrypt. Store secrets/breakglass.agekey somewhere safe
# (password manager, not this repo).
#
# Usage: sudo ./scripts/sops-breakglass.sh
set -eu

REPO=/home/ivali/nixos-infrastructure
cd "$REPO"

KEY="$REPO/secrets/breakglass.agekey"
SOPS_YAML="$REPO/.sops.yaml"

if [ ! -f "$KEY" ]; then
  mkdir -p "$(dirname "$KEY")"
  echo "Generating break-glass age key at $KEY ..."
  age-keygen -o "$KEY"
  chmod 400 "$KEY"
fi

PUB="$(age-keygen -y "$KEY")"

if grep -q "breakglass" "$SOPS_YAML"; then
  echo "break-glass already registered; re-encrypting with both keys."
else
  echo "Registering break-glass recipient ($PUB) ..."
  awk -v pub="$PUB" '
    /^keys:/ { print; getline; print "  - &breakglass " pub; print $0; next }
    /\*prague/ { print; print "          - *breakglass"; next }
    { print }
  ' "$SOPS_YAML" > "$SOPS_YAML.tmp" && mv "$SOPS_YAML.tmp" "$SOPS_YAML"
fi

echo "Re-encrypting secrets with the new recipient set ..."
# Requires the original age key to be available (sops.yaml still lists it).
sops updatekeys secrets/*.yaml

echo "Done. Either the original or the break-glass key can now decrypt secrets."
echo "Keep secrets/breakglass.agekey OFF this machine (password manager / USB)."
