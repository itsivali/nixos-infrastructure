#!/run/current-system/sw/bin/bash
# ci-deploy.sh — Acquire lock → nixos-rebuild switch → done
#
# Run by systemd ci-deploy.service (triggered from GitLab CI).
# Shares the lock with gitops-reconcile.sh to prevent concurrent deploys.
set -Eeuo pipefail

LOCK_FILE="/run/deploy.lock"
HOST="${HOST_NAME:-prague}"
REPO_DIR="${REPO_DIR:-/home/ivali/nixos-infrastructure}"

log() { echo "[$(date -Iseconds)] $*"; }

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  log "Another deployment is running — waiting up to 5 minutes..."
  flock -w 300 9 || {
    log "Timed out waiting for lock — aborting."
    exit 1
  }
fi

log "Lock acquired — deploying ${HOST}..."
cd "$REPO_DIR"

# Validate hardware UUIDs before rebuild to prevent boot failures
HW_CHECK="${REPO_DIR}/scripts/validate-hardware.sh"
if [[ -x "$HW_CHECK" ]]; then
  if ! "$HW_CHECK" --quiet; then
    log "🚨 Hardware UUID mismatch — aborting deploy"
    exit 1
  fi
fi

nixos-rebuild switch --flake ".#${HOST}" --show-trace
log "Deployment complete."
