#!/run/current-system/sw/bin/bash
# ci-deploy.sh — CI-triggered deploy with full gate parity with gitops-reconcile.sh
#
# Acquire lock → dirty-tree guard → flake check → nix eval → HW UUID → Go hash
# verify → build → switch → health gate → rollback on failure.
#
# Run by systemd ci-deploy.service (triggered from GitLab CI).
# Shares the lock with gitops-reconcile.sh to prevent concurrent deploys.
set -Eeuo pipefail

LOCK_FILE="/run/deploy.lock"
LOCK_MAX_AGE=1800  # 30 min — if lock is older, assume crash and remove
HOST="${HOST_NAME:-prague}"
REPO_DIR="${REPO_DIR:-/home/ivali/nixos-infrastructure}"

NOTIFY="${REPO_DIR}/scripts/notify.sh"
HEALTH="${REPO_DIR}/scripts/deployment-health.sh"
ROLLBACK="${REPO_DIR}/scripts/rollback.sh"
GITOPTS=(--flake ".#${HOST}" --show-trace)

log() { echo "[$(date -Iseconds)] $*"; }

notify() {
  if [[ -x "$NOTIFY" ]]; then
    "$NOTIFY" "$1" || true
  fi
}

###########################################################################
# Lock — stale detection + mutual exclusion (parity with gitops)
###########################################################################

exec 9>"$LOCK_FILE"

if ! flock -n 9; then
  lock_age=0
  if [[ -f "$LOCK_FILE" ]]; then
    now="$(date +%s)"
    mtime="$(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0)"
    lock_age=$(( now - mtime ))
  fi

  if [[ "$lock_age" -gt "$LOCK_MAX_AGE" ]]; then
    log "Stale lock detected (${lock_age}s old > ${LOCK_MAX_AGE}s max) — removing."
    rm -f "$LOCK_FILE"
    exec 9>"$LOCK_FILE"
    if ! flock -n 9; then
      log "Still cannot acquire lock after clearing stale file — skipping."
      exit 0
    fi
  else
    log "Another deployment is running — skipping."
    exit 0
  fi
fi

log "Lock acquired — deploying ${HOST}..."
cd "$REPO_DIR"

###########################################################################
# Dirty-tree guard — comprehensive check (parity with gitops)
###########################################################################

dirty=false
dirty_reason=""

if ! git diff --quiet 2>/dev/null; then
  dirty=true
  dirty_reason="modified tracked files"
fi

if ! git diff --cached --quiet 2>/dev/null; then
  dirty=true
  dirty_reason="staged changes"
fi

untracked=$(git ls-files --others --exclude-standard 2>/dev/null | grep -v "^result$" | head -1)
if [[ -n "$untracked" ]]; then
  dirty=true
  dirty_reason="untracked files"
fi

if [[ -d ".git/MERGE_HEAD" ]] || [[ -f ".git/MERGE_MSG" ]]; then
  dirty=true
  dirty_reason="merge in progress"
fi

if ! git symbolic-ref -q HEAD >/dev/null 2>&1; then
  dirty=true
  dirty_reason="detached HEAD"
fi

if [[ "$dirty" == "true" ]]; then
  notify "⚠️ ci-deploy skipped: ${dirty_reason} on ${HOST}"
  log "Working tree dirty (${dirty_reason}) — aborting."
  exit 1
fi

###########################################################################
# Validate flake (parity with gitops)
###########################################################################

log "Flake check"
if ! nix flake check --show-trace; then
  notify "❌ Flake check failed on ${HOST} (ci-deploy)"
  log "Flake check failed — aborting."
  exit 1
fi

###########################################################################
# Validate configuration evaluates (parity with rebuild.sh)
###########################################################################

log "Configuration evaluation"
if ! nix eval ".#nixosConfigurations.${HOST}.config.system.build.toplevel.name" >/dev/null; then
  notify "❌ Configuration evaluation failed on ${HOST} (ci-deploy)"
  log "Configuration evaluation failed — aborting."
  exit 1
fi

###########################################################################
# Validate hardware UUIDs before rebuild to prevent boot failures
###########################################################################

HW_CHECK="${REPO_DIR}/scripts/validate-hardware.sh"
if [[ -x "$HW_CHECK" ]]; then
  if ! "$HW_CHECK" --quiet; then
    notify "🚨 Hardware UUID mismatch on ${HOST} — aborting deploy"
    log "Hardware UUID mismatch — aborting."
    exit 1
  fi
else
  log "validate-hardware.sh not found or not executable, skipping"
fi

###########################################################################
# Validate Go vendor hashes (parity with gitops)
###########################################################################

HASH_CHECK="${REPO_DIR}/scripts/update-go-hashes.sh"
if [[ -x "$HASH_CHECK" ]]; then
  if ! "$HASH_CHECK" --verify-only; then
    notify "🚨 Stale Go vendorHash detected on ${HOST} — run update-go-hashes.sh to fix"
    log "Stale Go vendorHash — aborting."
    exit 1
  fi
else
  log "update-go-hashes.sh not found or not executable, skipping"
fi

###########################################################################
# Build (parity with gitops — fail before touching the live system)
###########################################################################

log "Build system"
if ! nix build ".#nixosConfigurations.${HOST}.config.system.build.toplevel"; then
  notify "❌ Build failed on ${HOST} (ci-deploy)"
  log "Build failed — aborting before switch."
  exit 1
fi

###########################################################################
# Activate
###########################################################################

log "Activate (nixos-rebuild switch)"
if ! nixos-rebuild switch "${GITOPTS[@]}"; then
  notify "❌ Activation failed on ${HOST} (ci-deploy)"
  log "Activation failed."
  exit 1
fi

###########################################################################
# Grace period + health gate — rollback on failure (parity with gitops)
###########################################################################

log "Waiting for services to settle..."
sleep 30

health_passed=false
health_output=""

if [[ -x "$HEALTH" ]]; then
  log "Using runtime service health check (deployment-health.sh)..."
  if health_output="$("$HEALTH" 2>&1)"; then
    health_passed=true
  fi
else
  log "No health check tool available — skipping health gate."
  health_passed=true
fi

if ! "$health_passed"; then
  log "Health check output:"
  log "${health_output}"
  notify "🚨 Health check FAILED on ${HOST} (ci-deploy) — rolling back"
  log "Initiating rollback..."
  "$ROLLBACK"
  exit 1
fi

log "Deployment complete."