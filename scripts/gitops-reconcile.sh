#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

git fetch origin

LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [[ "$LOCAL" == "$REMOTE" ]]; then
  echo "No changes"
  exit 0
fi

echo "Changes detected"

git pull --ff-only

nix flake check || {
  ./scripts/notify.sh "❌ flake check failed"
  exit 1
}

sudo nixos-rebuild switch --flake .#prague || {
  ./scripts/notify.sh "❌ rebuild failed"
  exit 1
}

./scripts/deployment-health.sh || {
  ./scripts/notify.sh "❌ health check failed → rollback"
  ./scripts/rollback.sh
  exit 1
}

./scripts/notify.sh "✅ system updated successfully"
