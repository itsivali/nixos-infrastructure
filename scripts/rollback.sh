#!/run/current-system/sw/bin/bash
# rollback.sh — roll back to the previous NixOS generation and notify
#
# Called by gitops-reconcile.sh when health check fails post-deploy.
# Also safe to call manually: sudo ./scripts/rollback.sh

set -Eeuo pipefail

REPO_DIR="/home/ivali/nixos-infrastructure"
NOTIFY="${REPO_DIR}/scripts/notify.sh"
HEALTH="${REPO_DIR}/scripts/deployment-health.sh"

HOST="prague"

log() { echo "[$(date -Iseconds)] $*"; }

notify() {
  if [[ -x "$NOTIFY" ]]; then "$NOTIFY" "$1" || true; fi
}

###########################################################################
# Capture current generation
###########################################################################

CURRENT_GEN="$(
  nix-env --list-generations --profile /nix/var/nix/profiles/system \
    | tail -1 | awk '{print $1}'
)"
log "Rolling back from generation ${CURRENT_GEN}..."

###########################################################################
# Roll back
###########################################################################

if ! nixos-rebuild switch --rollback; then
  notify "❌ Rollback command FAILED on ${HOST} — manual intervention required"
  log "nixos-rebuild --rollback failed."
  exit 1
fi

ROLLED_TO="$(
  nix-env --list-generations --profile /nix/var/nix/profiles/system \
    | tail -1 | awk '{print $1}'
)"

###########################################################################
# Verify health after rollback
###########################################################################

sleep 10  # let services settle

if "$HEALTH"; then
  notify "✅ Rollback successful on ${HOST}

Rolled back : generation ${CURRENT_GEN} → ${ROLLED_TO}
Health      : OK after rollback
Time        : $(date -Iseconds)"
  log "Rollback to generation ${ROLLED_TO} complete. Health OK."
else
  notify "🚨 Rollback done but health STILL FAILING on ${HOST}

Generation  : ${CURRENT_GEN} → ${ROLLED_TO}
Status      : Manual intervention required
Time        : $(date -Iseconds)"
  log "Post-rollback health check also failed — escalation needed."
  exit 1
fi
