#!/run/current-system/sw/bin/bash
# rollback.sh — THE single rollback authority for this node.
#
# Every rollback path delegates here:
#   - gitops-reconcile.sh (post-deploy health gate)
#   - rollback-on-failure.service (gitops reconciler OnFailure)
#   - manual operator invocation: sudo ./scripts/rollback.sh
#
# This script owns:
#   - Concurrency control (flock) so two paths cannot race nixos-rebuild
#   - Hysteresis (cooldown): refuses to re-rollback within 15 minutes of a
#     previous rollback, breaking a tight rollback → fail → rollback loop.
#   - The single nixos-rebuild switch --rollback invocation.
#   - Post-rollback health gate + operator notification.
#
# All other rollback paths MUST call this script; they must not invoke
# nixos-rebuild --rollback themselves.

set -Eeuo pipefail

REPO_DIR="/home/ivali/nixos-infrastructure"
NOTIFY="${REPO_DIR}/scripts/notify.sh"
HEALTH="${REPO_DIR}/scripts/deployment-health.sh"
IVALI="$(command -v ivali 2>/dev/null || echo "${REPO_DIR}/result/bin/ivali")"

HOST="${HOST_NAME:-$(hostname)}"

# Hysteresis: minimum seconds between two rollbacks.
COOLDOWN_SECONDS="${COOLDOWN_SECONDS:-900}"
# Lock file prevents concurrent rollbacks from racing the system profile.
ROLLBACK_LOCK="/run/rollback.lock"
# Remediation timestamp dir (matches deployment-health.sh results dir).
COOLDOWN_STATE_DIR="${COOLDOWN_STATE_DIR:-/var/lib/deployment-health}"

log() { echo "[$(date -Iseconds)] $*"; }

notify() {
  if [[ -x "$NOTIFY" ]]; then "$NOTIFY" "$1" || true; fi
}

###########################################################################
# Concurrency control — single flyweight for all rollback callers
###########################################################################

exec 9>"$ROLLBACK_LOCK"
if ! flock -n 9; then
  log "Another rollback is already running — exiting."
  exit 0
fi

###########################################################################
# Hysteresis — suppress re-rollback within the cooldown window
###########################################################################

mkdir -p "$COOLDOWN_STATE_DIR" 2>/dev/null || true
LAST="${COOLDOWN_STATE_DIR}/last-remediation"
if [[ -f "$LAST" ]]; then
  LAST_EPOCH="$(cat "$LAST" 2>/dev/null || echo 0)"
  NOW_EPOCH="$(date +%s)"
  if [[ "$LAST_EPOCH" =~ ^[0-9]+$ ]] && (( NOW_EPOCH - LAST_EPOCH < COOLDOWN_SECONDS )); then
    remaining=$(( COOLDOWN_SECONDS - (NOW_EPOCH - LAST_EPOCH) ))
    log "Rollback cooldown active — last remediation $(date -d @"$LAST_EPOCH" -Iseconds 2>/dev/null || echo "$LAST_EPOCH"); skipping for ${remaining}s."
    exit 0
  fi
fi

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
if [[ "$(id -u)" -eq 0 ]]; then
  ROLLBACK_OUTPUT=$(nixos-rebuild switch --rollback 2>&1) || {
    notify "❌ Rollback command FAILED on ${HOST} — manual intervention required

Generation: ${CURRENT_GEN}
Error output:
$(echo "$ROLLBACK_OUTPUT" | tail -10)"
    log "nixos-rebuild switch --rollback failed."
    log "$ROLLBACK_OUTPUT"
    exit 1
  }
else
  ROLLBACK_OUTPUT=$(sudo nixos-rebuild switch --rollback 2>&1) || {
    notify "❌ Rollback command FAILED on ${HOST} — manual intervention required

Generation: ${CURRENT_GEN}
Error output:
$(echo "$ROLLBACK_OUTPUT" | tail -10)"
    log "nixos-rebuild switch --rollback failed."
    log "$ROLLBACK_OUTPUT"
    exit 1
  }
fi

ROLLED_TO="$(
  nix-env --list-generations --profile /nix/var/nix/profiles/system \
    | tail -1 | awk '{print $1}'
)"

###########################################################################
# Record remediation timestamp (hysteresis). Written here so that even if
# the post-rollback health gate fails, a subsequent rollback-on-failure
# cycle will be suppressed within the cooldown window.
###########################################################################

if date +%s > "$COOLDOWN_STATE_DIR/last-remediation" 2>/dev/null; then
  log "Recorded remediation timestamp at ${COOLDOWN_STATE_DIR}/last-remediation."
else
  log "WARNING: could not write remediation timestamp (${COOLDOWN_STATE_DIR} not writable)."
fi

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
