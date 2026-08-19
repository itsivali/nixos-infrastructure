#!/run/current-system/sw/bin/bash
# rollback.sh — roll back to the previous NixOS generation and notify
#
# Called by gitops-reconcile.sh when health check fails post-deploy.
# Also safe to call manually: sudo ./scripts/rollback.sh

set -Eeuo pipefail

REPO_DIR="/home/ivali/nixos-infrastructure"
NOTIFY="${REPO_DIR}/scripts/notify.sh"
HEALTH="${REPO_DIR}/scripts/deployment-health.sh"
IVALI="$(command -v ivali 2>/dev/null || echo "${REPO_DIR}/result/bin/ivali")"

HOST="${HOST_NAME:-$(hostname)}"

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

# Use --rollback to revert to the previous generation. The --flake form
# does not support rollback directly; --rollback is a standalone flag.
ROLLBACK_OUTPUT=$(sudo nixos-rebuild switch --rollback 2>&1) || {
  notify "❌ Rollback command FAILED on ${HOST} — manual intervention required

Generation: ${CURRENT_GEN}
Error output:
$(echo "$ROLLBACK_OUTPUT" | tail -10)"
  log "nixos-rebuild switch --rollback failed."
  log "$ROLLBACK_OUTPUT"
  exit 1
}

ROLLED_TO="$(
  nix-env --list-generations --profile /nix/var/nix/profiles/system \
    | tail -1 | awk '{print $1}'
)"

###########################################################################
# Verify health after rollback
###########################################################################

sleep 10  # let services settle

health_passed=false
if [[ -x "$IVALI" ]]; then
  log "Using ivali doctor for health check..."
  if "$IVALI" doctor > /dev/null 2>&1; then
    health_passed=true
  fi
elif [[ -x "$HEALTH" ]]; then
  log "Using legacy deployment-health.sh..."
  if "$HEALTH"; then
    health_passed=true
  fi
else
  log "No health check tool available — skipping health gate."
  health_passed=true
fi

if "$health_passed"; then
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
