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

# Production GitOps checkout — NOT the developer's home directory.
# This is the single source of truth for the local git worktree.
# CI and recovery are read-only consumers through documented interfaces.
REPO_DIR="/var/lib/gitops"
SCRIPTS_DIR="${REPO_DIR}/scripts"
NOTIFY="${SCRIPTS_DIR}/notify.sh"
HEALTH="${SCRIPTS_DIR}/deployment-health.sh"
ROLLBACK="${SCRIPTS_DIR}/rollback.sh"
IVALI="$(command -v ivali 2>/dev/null || echo "${REPO_DIR}/result/bin/ivali")"

HOST="${HOST_NAME:-$(hostname)}"
BRANCH="${GITOPS_BRANCH:-main}"
GIT_REMOTE="${GITOPS_REPO:-git@gitlab.com:willisivali/nixos-infrastructure.git}"
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
    if "$@" 2>&1; then
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
# Repo sanity — provision if missing
###########################################################################

if [[ ! -d "${REPO_DIR}/.git" ]]; then
  log "Git repository missing at ${REPO_DIR} — provisioning..."
  
  # Ensure parent directory exists
  mkdir -p "$(dirname "${REPO_DIR}")"
  
  # Clone the repository
  if ! retry "git clone" git clone --depth 1 --branch "${BRANCH}" "${GIT_REMOTE}" "${REPO_DIR}"; then
    notify "❌ GitOps failure: failed to clone repository on ${HOST}"
    log "Failed to clone repository from ${GIT_REMOTE}"
    exit 1
  fi
  
  # Set proper ownership
  chown -R ivali:users "${REPO_DIR}"
  chmod 700 "${REPO_DIR}"
  
  log "Repository provisioned at ${REPO_DIR}"
fi

cd "$REPO_DIR"

###########################################################################
# Dirty-tree guard — comprehensive check
###########################################################################

dirty=false
dirty_reason=""

# Check for modified tracked files
if ! git diff --quiet 2>/dev/null; then
  dirty=true
  dirty_reason="modified tracked files"
fi

# Check for staged changes
if ! git diff --cached --quiet 2>/dev/null; then
  dirty=true
  dirty_reason="staged changes"
fi

# Check for untracked files (exclude .result if present)
# `grep -v` exits 1 when nothing matches; `|| true` is REQUIRED under
# `set -Eeuo pipefail` or a clean checkout instantly aborts the script.
untracked=$(git ls-files --others --exclude-standard 2>/dev/null | grep -v "^result$" | head -1 || true)
if [[ -n "$untracked" ]]; then
  dirty=true
  dirty_reason="untracked files"
fi

# Check for merge conflicts
if [[ -d ".git/MERGE_HEAD" ]] || [[ -f ".git/MERGE_MSG" ]]; then
  dirty=true
  dirty_reason="merge in progress"
fi

# Check for detached HEAD
if ! git symbolic-ref -q HEAD >/dev/null 2>&1; then
  dirty=true
  dirty_reason="detached HEAD"
fi

if [[ "$dirty" == "true" ]]; then
  notify "⚠️ GitOps skipped: ${dirty_reason} on ${HOST}"
  log "Working tree dirty (${dirty_reason}) — skipping."
  exit 1
fi

###########################################################################
# Fetch and compare (with retry)
###########################################################################

step "Fetch origin"
if ! retry "git fetch" git fetch --prune origin; then
  # Network failure safety: if we can't fetch, the system is still fine
  # Just skip this reconciliation cycle and try again later
  log "Network unavailable or git fetch failed — keeping current configuration"
  log "System is healthy, just unreachable. Will retry next cycle."
  exit 0
fi
step_ok

###########################################################################
# Corruption recovery
###########################################################################

step "Check repository integrity"
if ! git fsck --no-dangling >/dev/null 2>&1; then
  log "Repository corruption detected — re-cloning..."
  rm -rf "${REPO_DIR}"
  if ! retry "git clone" git clone --depth 1 --branch "${BRANCH}" "${GIT_REMOTE}" "${REPO_DIR}"; then
    notify "❌ GitOps failure: repository corruption and clone failed on ${HOST}"
    step_fail
    exit 1
  fi
  cd "$REPO_DIR"
  log "Repository re-cloned successfully"
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

# The reconciler runs as the unprivileged `ivali` user (`5386fb8`), so it must
# NOT use `nix-env --list-generations --profile /nix/var/nix/profiles/system`:
# that opens root-owned `/nix/var/nix/profiles/system.lock` and every reconcile
# dies with "Permission denied" right after a successful fetch. `readlink` on
# the system profile symlink is world-readable and parseable instead.
CURRENT_GEN="$(readlink /nix/var/nix/profiles/system | sed -E 's/.*system-([0-9]+)-link.*/\1/')"
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
# Validate hardware UUIDs
###########################################################################

step "Validate hardware UUIDs"
HW_CHECK="${REPO_DIR}/scripts/validate-hardware.sh"
if [[ -x "$HW_CHECK" ]]; then
  if ! "$HW_CHECK" --quiet; then
    notify "🚨 Hardware UUID mismatch on ${HOST} — aborting deploy"
    step_fail
    exit 1
  fi
else
  log "validate-hardware.sh not found or not executable, skipping"
fi
step_ok

###########################################################################
# Validate Go vendor hashes
###########################################################################

step "Check Go vendor hashes"
HASH_CHECK="${REPO_DIR}/scripts/update-go-hashes.sh"
if [[ -x "$HASH_CHECK" ]]; then
  if ! "$HASH_CHECK" --verify-only; then
    notify "🚨 Stale Go vendorHash detected on ${HOST} — run update-go-hashes.sh to fix"
    step_fail
    exit 1
  fi
else
  log "update-go-hashes.sh not found or not executable, skipping"
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
# Canary gate (optional) — validate the NixOS VM test derivation
# builds before we touch bare metal. Set GITOPS_CANARY=1 to enable.
# A full headless boot-run needs KVM+QEMU; building the test
# derivation below catches the majority of config regressions
# (broken module imports, bad options) cheaply, before `switch`.
# (tests/laptop-smoke.nix must exist for the .vm attr to resolve.)
###########################################################################
step "Canary VM test"
if [[ "${GITOPS_CANARY:-0}" == "1" ]]; then
  if command -v nixos-rebuild >/dev/null 2>&1; then
    if ! nix build ".#nixosConfigurations.${HOST}.config.system.build.vm" --show-trace; then
      notify "🚨 Canary VM build failed on ${HOST} — aborting deploy"
      step_fail
      exit 1
    fi
  else
    log "Canary: nixos-rebuild unavailable, skipping VM derivation build."
  fi
else
  log "Canary disabled (GITOPS_CANARY=1 to gate deploys behind a VM test)."
fi
step_ok

###########################################################################
# Activate
###########################################################################

step "Activate (sudo nixos-rebuild switch)"
if ! sudo nixos-rebuild switch --flake ".#${HOST}" --show-trace; then
  notify "❌ Activation failed on ${HOST} (${SHORT_SHA})"
  step_fail
  exit 1
fi
step_ok

###########################################################################
# Grace period — let services settle after rebuild before health gate
###########################################################################

step "Waiting for services to settle..."
sleep 30
ok "Grace period complete"

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

NEW_GEN="$(readlink /nix/var/nix/profiles/system | sed -E 's/.*system-([0-9]+)-link.*/\1/')"

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
