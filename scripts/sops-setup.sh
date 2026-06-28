#!/usr/bin/env bash
set -euo pipefail

KEY_DIR="/home/ivali/.config/sops/age"
KEY_FILE="${KEY_DIR}/keys.txt"

echo "Creating SOPS Age key directory..."
mkdir -p "$KEY_DIR"

echo "Writing Age key..."
cat > "$KEY_FILE" <<'EOF'
# created: 2026-06-09T01:00:11+03:00
# public key: age1ps5ptfp4yg87lnzurdfllnmwezvjjyx5j2lqkzsvk8zkfja0n3rsyhuawn
AGE-SECRET-KEY-1LU3NPNFCEKUHDY6006M8AYJWD7XDLUDJZ3CYCQPNSC3LAYMVV3KQKXQ6G9
EOF

chmod 700 "$KEY_DIR"
chmod 600 "$KEY_FILE"

echo
echo "✅ SOPS Age key installed successfully."
echo "Location: $KEY_FILE"
