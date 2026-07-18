#!/run/current-system/sw/bin/bash
# gitops-reconcile.sh — pull → build → switch → health → rollback on failure
#
# Run by systemd gitops-reconciler.service every 15 minutes.
# Uses a lock file so concurrent timer fires cannot race.
# Includes stale lock detection, retry with backoff, step timing, and
# optional integration with the ivali CLI doctor.

set -Eeuo pipefail

###########################################################################
# Config
###########################################################################

# Local checkout the loop operates on. NOTE: GITOPS_REPO (config.fleet.gitops.repo)
# is a remote *URL* (https://gitlab.com/...), not a local path, so it cannot be
# used here. The intended GITOPS_WORKTREE (/var/lib/gitops) is never provisioned,
# so we use the operator's existing checkout.
REPO_DIR="/home/ivali/nixos-infrastructure"
SCRIPTS_DIR="${REPO_DIR}/scripts"
NOTIFY="${SCRIPTS_DIR}/notify.sh"
HEALTH="${SCRIPTS_DIR}/deployment-health.sh"
ROLLBACK="${SCRIPTS_DIR}/rollback.sh"
IVALI="$(command -v ivali 2>/dev/null || echo "${REPO_DIR}/result/bin/ivali")"

HOST="prague"
BRANCH="main"
LOCK_FILE="/run/deploy.lock"
LOCK_MAX_AGE=1800  # 30 min — if lock is older, assume crash and remove

# Retry config (overridable via env)
MAX_RETRIES="${GITOPS_MAX_RETRIES:-3}"
RETRY_DELAY="${GITOPS_RETRY_DELAY:-5}"  # initial delay in seconds
USE_IVALI="${GITOPS_USE_IVALI_DOCTOR:-true}"

###########################################################################
# Helpers
###########################################################################

log() { echo "[$(date -Iseconds)] $*"; }
GLOBAL_START="$SECONDS"
step_start=""
step_name=""

step() {
  step_name="$1"
  step_start="$SECONDS"
  log "▶ $*"
}

step_ok() {
  local elapsed=$(( SECONDS - step_start ))
  log "✓ ${step_name} (${elapsed}s)"
}

step_fail() {
  local elapsed=$(( SECONDS - step_start ))
  log "✗ ${step_name} (${elapsed}s)"
}

notify() {
  if [[ -x "$NOTIFY" ]]; then
    "$NOTIFY" "$1" || true
  fi
}

# Retry a command with exponential backoff
retry() {
  local attempt=1
  local delay="$RETRY_DELAY"
  local cmd_desc="$1"
  shift

  while true; do
    if "$@" 2>/dev/null; then
      return 0
    fi
    if [[ "$attempt" -ge "$MAX_RETRIES" ]]; then
      log "Retry exhausted for: ${cmd_desc} (${attempt}/${MAX_RETRIES})"
      return 1
    fi
    log "Retry ${attempt}/${MAX_RETRIES} for: ${cmd_desc} — waiting ${delay}s..."
    sleep "$delay"
    attempt=$(( attempt + 1 ))
    delay=$(( delay * 2 ))  # exponential backoff
  done
}

###########################################################################
# Lock — stale detection + mutual exclusion
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
    log "Another reconciliation already running — skipping."
    exit 0
  fi
fi

###########################################################################
# Repo sanity
###########################################################################

if [[ ! -d "${REPO_DIR}/.git" ]]; then
  notify "❌ GitOps failure: repo missing on ${HOST}"
  log "Repo missing at ${REPO_DIR}"
  exit 1
fi

cd "$REPO_DIR"

###########################################################################
# Dirty-tree guard
###########################################################################

if ! git diff --quiet; then
  notify "⚠️ GitOps skipped: uncommitted local changes on ${HOST}"
  log "Working tree dirty — skipping."
  exit 1
fi

###########################################################################
# Fetch and compare (with retry)
###########################################################################

step "Fetch origin"
if ! retry "git fetch" git fetch --prune origin; then
  notify "❌ GitOps failure: git fetch failed on ${HOST}"
  step_fail
  exit 1
fi
step_ok

LOCAL="$(git rev-parse HEAD)"
REMOTE="$(git rev-parse "origin/${BRANCH}")"

log "LOCAL  = ${LOCAL}"
log "REMOTE = ${REMOTE}"

if [[ "$LOCAL" == "$REMOTE" ]]; then
  log "Already up-to-date."
  exit 0
fi

###########################################################################
# Capture rollback anchor before we touch anything
###########################################################################

CURRENT_GEN="$(
  nix-env --list-generations --profile /nix/var/nix/profiles/system \
    | tail -1 | awk '{print $1}'
)"
log "Current generation: ${CURRENT_GEN}"

OLD_SHA="$LOCAL"

###########################################################################
# Pull (with retry)
###########################################################################

step "Pull updates"
if ! retry "git pull" git pull --ff-only origin "${BRANCH}"; then
  notify "❌ GitOps failure: git pull failed on ${HOST}"
  step_fail
  exit 1
fi
step_ok

SHORT_SHA="$(git rev-parse --short HEAD)"
CHANGELOG="$(git log --oneline "${OLD_SHA}..HEAD")"
CHANGED_FILES="$(git diff --name-only "${OLD_SHA}..HEAD")"

###########################################################################
# Validate flake
###########################################################################

step "Flake check"
if ! nix flake check --show-trace; then
  notify "❌ Flake check failed on ${HOST} (${SHORT_SHA})"
  step_fail
  exit 1
fi
step_ok

###########################################################################
# Build
###########################################################################

step "Build system"
if ! nix build ".#nixosConfigurations.${HOST}.config.system.build.toplevel"; then
  notify "❌ Build failed on ${HOST} (${SHORT_SHA})"
  step_fail
  exit 1
fi
step_ok

###########################################################################
# Activate
###########################################################################

step "Activate (nixos-rebuild switch)"
if ! nixos-rebuild switch --flake ".#${HOST}" --show-trace; then
  notify "❌ Activation failed on ${HOST} (${SHORT_SHA})"
  step_fail
  exit 1
fi
step_ok

###########################################################################
# Health gate — prefer runtime service health (deployment-health.sh); fall
# back to ivali doctor (config quality) only if the runtime check is absent.
###########################################################################

step "Health check"

health_passed=false
health_output=""

if [[ -x "$HEALTH" ]]; then
  log "Using runtime service health check (deployment-health.sh)..."
  if health_output="$("$HEALTH" 2>&1)"; then
    health_passed=true
  fi
elif [[ "$USE_IVALI" == "true" && -x "$IVALI" ]]; then
  log "Using ivali doctor for health check..."
  if health_output="$("$IVALI" doctor 2>&1)"; then
    health_passed=true
  fi
else
  log "No health check tool available — skipping health gate."
  health_passed=true
fi

if ! "$health_passed"; then
  log "Health check output:"
  log "${health_output}"
  notify "🚨 Health check FAILED on ${HOST} — rolling back"
  log "Initiating rollback..."
  "$ROLLBACK"
  step_fail
  exit 1
fi
step_ok

###########################################################################
# Success
###########################################################################

NEW_GEN="$(
  nix-env --list-generations --profile /nix/var/nix/profiles/system \
    | tail -1 | awk '{print $1}'
)"

TOTAL_ELAPSED=$(( SECONDS - GLOBAL_START ))

notify "✅ ${HOST} updated successfully

Generation    : ${CURRENT_GEN} → ${NEW_GEN}
Commit        : ${SHORT_SHA}
Branch        : ${BRANCH}
Duration      : ${TOTAL_ELAPSED}s
Time          : $(date -Iseconds)

Changes
───────
${CHANGELOG}

Files touched
─────────────
${CHANGED_FILES}"

log "Reconciliation complete (${TOTAL_ELAPSED}s)."
